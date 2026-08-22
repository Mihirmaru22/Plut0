import crypto from "node:crypto";
import { dbAdapter } from "./adapter.js";

export interface GhostStatusRecord {
  activeSeason: {
    id: string;
    name: string;
    protocolKind: string;
    doctrine: string;
    startDate: string;
    endDate: string;
    elapsedDays: number;
    totalDays: number;
  } | null;
  todayRecord: {
    date: string;
    bodyClosed: boolean;
    mindClosed: boolean;
    silenceClosed: boolean;
    ghostDay: boolean;
    score: number;
    silenceMinutesVerified: number;
    silenceMinutesAttested: number;
  } | null;
  streak: number;
  rank: string;
}

export class GhostRepository {
  public getGhostStatus(): GhostStatusRecord {
    const seasonRow = dbAdapter.queryOne<any>(
      `SELECT id, name, protocol_kind, start_date, end_date, doctrine, signed_at, device_id
       FROM ghost_seasons
       ORDER BY signed_at DESC
       LIMIT 1;`
    );

    if (!seasonRow) {
      return {
        activeSeason: null,
        todayRecord: null,
        streak: 0,
        rank: "Uninitiated",
      };
    }

    const startDate = new Date(seasonRow.start_date * 1000);
    const endDate = new Date(seasonRow.end_date * 1000);
    const today = new Date();
    const elapsedDays = Math.max(1, Math.round((today.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)));
    const totalDays = Math.max(1, Math.round((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)));

    const todayStr = today.toISOString().split("T")[0];
    const dayRow = dbAdapter.queryOne<any>(
      `SELECT id, season_id, date, body_closed, mind_closed, silence_closed,
              ghost_day, score, silence_minutes_verified, silence_minutes_attested
       FROM ghost_days
       WHERE season_id = ? AND date = ?;`,
      [seasonRow.id, todayStr]
    );

    const allDays = dbAdapter.queryAll<any>(
      `SELECT date, ghost_day FROM ghost_days WHERE season_id = ? ORDER BY date ASC;`,
      [seasonRow.id]
    );

    let streak = 0;
    for (const d of allDays) {
      if (d.ghost_day === 1) {
        streak += 1;
      } else if (d.date !== todayStr) {
        if (seasonRow.doctrine === "hard") {
          streak = 0;
        } else {
          streak = Math.max(0, streak - 1);
        }
      }
    }

    let rank = "Apparition";
    if (streak >= 120) rank = "Ghost Sovereign";
    else if (streak >= 75) rank = "Specter";
    else if (streak >= 45) rank = "Wraith";
    else if (streak >= 21) rank = "Phantom";
    else if (streak >= 7) rank = "Shadow";
    else if (streak >= 1) rank = "Apparition";
    else rank = "Uninitiated";

    return {
      activeSeason: {
        id: seasonRow.id,
        name: seasonRow.name,
        protocolKind: seasonRow.protocol_kind,
        doctrine: seasonRow.doctrine,
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
        elapsedDays,
        totalDays,
      },
      todayRecord: dayRow
        ? {
            date: dayRow.date,
            bodyClosed: dayRow.body_closed === 1,
            mindClosed: dayRow.mind_closed === 1,
            silenceClosed: dayRow.silence_closed === 1,
            ghostDay: dayRow.ghost_day === 1,
            score: dayRow.score,
            silenceMinutesVerified: dayRow.silence_minutes_verified,
            silenceMinutesAttested: dayRow.silence_minutes_attested,
          }
        : null,
      streak,
      rank,
    };
  }

  public checkIn(input: {
    bodyClosed?: boolean;
    mindClosed?: boolean;
    silenceMinutes?: number;
    reflectionNote?: string;
  }): { success: boolean; score: number; isGhostDay: boolean } {
    const seasonRow = dbAdapter.queryOne<any>(
      `SELECT id, doctrine FROM ghost_seasons ORDER BY signed_at DESC LIMIT 1;`
    );
    if (!seasonRow) {
      return { success: false, score: 0, isGhostDay: false };
    }

    const todayStr = new Date().toISOString().split("T")[0];
    const existing = dbAdapter.queryOne<any>(
      `SELECT * FROM ghost_days WHERE season_id = ? AND date = ?;`,
      [seasonRow.id, todayStr]
    );

    const bodyClosed = input.bodyClosed !== undefined ? (input.bodyClosed ? 1 : 0) : existing ? existing.body_closed : 0;
    const mindClosed = input.mindClosed !== undefined ? (input.mindClosed ? 1 : 0) : input.reflectionNote ? 1 : existing ? existing.mind_closed : 0;
    const attested = input.silenceMinutes !== undefined ? input.silenceMinutes : existing ? existing.silence_minutes_attested : 0;
    const verified = existing ? existing.silence_minutes_verified : 0;
    const silenceClosed = (verified + attested >= 45) ? 1 : existing ? existing.silence_closed : 0;

    const isGhost = (bodyClosed === 1 && mindClosed === 1 && silenceClosed === 1) ? 1 : 0;
    let score = 0;
    if (bodyClosed === 1) score += 25;
    if (mindClosed === 1) score += 25;
    if (silenceClosed === 1) score += 25;
    score += Math.min(25, Math.round(((verified + attested / 2) / 90) * 25));
    score = Math.min(100, Math.max(0, score));

    const dayId = existing ? existing.id : crypto.randomUUID();
    const now = Date.now() / 1000;

    dbAdapter.execute(
      `INSERT OR REPLACE INTO ghost_days (
        id, season_id, date, body_closed, mind_closed, silence_closed,
        ghost_day, score, silence_minutes_verified, silence_minutes_attested,
        offline_intervals_json, reflection_note_id, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);`,
      [
        dayId,
        seasonRow.id,
        todayStr,
        bodyClosed,
        mindClosed,
        silenceClosed,
        isGhost,
        score,
        verified,
        attested,
        existing ? existing.offline_intervals_json : "[]",
        input.reflectionNote ? "ai_note" : existing ? existing.reflection_note_id : null,
        now,
      ]
    );

    return {
      success: true,
      score,
      isGhostDay: isGhost === 1,
    };
  }
}

export const ghostRepo = new GhostRepository();
