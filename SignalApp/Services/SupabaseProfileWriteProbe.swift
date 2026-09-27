//
//  SupabaseProfileWriteProbe.swift
//  SignalApp
//

import Foundation
import Helpers

enum SupabaseProfileWriteProbe {
    /// Postgres/PostgREST 오류 — throw/catch 시 **항상** 풀 출력 (숨기지 않음).
    static func logError(context: String, error: Error) {
        print("━━━━━━━━ 🔴 [Supabase ERROR] \(context) ━━━━━━━━")

        if let postgres = error as? PostgrestError {
            print("type=PostgrestError")
            print("code=\(postgres.code ?? "<nil>")")
            print("message=\(postgres.message)")
            print("detail=\(postgres.detail ?? "<nil>")")
            print("hint=\(postgres.hint ?? "<nil>")")
            if postgres.code == "42501" {
                print("diagnosis=RLS policy violation (42501)")
                print("fix=1) Auth Anonymous ON  2) user_metadata.device_user_id=profiles.id")
                print("fix=3) Run Docs/SupabaseAPNsProfiles.sql")
                print("test=Run Docs/SupabaseAPNsProfiles-RLS-DISABLE-TEST.sql then relaunch app")
            }
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return
        }

        if let http = error as? HTTPError {
            let body = String(data: http.data, encoding: .utf8) ?? "<non-utf8 \(http.data.count) bytes>"
            print("type=HTTPError")
            print("status=\(http.response.statusCode)")
            print("body=\(body)")
            if let parsed = try? JSONDecoder().decode(PostgrestError.self, from: http.data) {
                print("parsed.code=\(parsed.code ?? "<nil>")")
                print("parsed.message=\(parsed.message)")
                print("parsed.detail=\(parsed.detail ?? "<nil>")")
                print("parsed.hint=\(parsed.hint ?? "<nil>")")
            }
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return
        }

        print("type=\(type(of: error))")
        print("localized=\(error.localizedDescription)")
        print("debug=\(String(reflecting: error))")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    /// HTTP 2xx인데 `return=representation`이 비었을 때 — RLS silent block 의심.
    static func logSilentRLSBlock(context: String, profileId: String) {
        print(
            """
            ━━━━━━━━ 🟠 [Profiles RLS SILENT?] \(context) ━━━━━━━━
            profiles.id=\"\(profileId)\"
            INSERT/upsert threw NO error but returned 0 rows.
            Supabase often hides RLS failures as empty results on SELECT; INSERT may return empty representation.
            TEST: SQL Editor → Docs/SupabaseAPNsProfiles-RLS-DISABLE-TEST.sql
            Then relaunch app — if rows appear, fix RLS + Anonymous auth metadata.
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            """
        )
    }

    static func logSuccess(context: String, profileId: String, extra: String = "") {
        print("🟢 [Profiles DB OK] \(context) id=\"\(profileId)\" \(extra)")
    }
}
