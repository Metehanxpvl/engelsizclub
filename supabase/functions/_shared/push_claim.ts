// İstemci broadcast-push + SQL notify-push aynı anahtarı kullanır.

export function insertDedupeKey(row: {
  type?: string;
  owner_email?: string;
  actor_email?: string;
  sohbet_key?: string | null;
  ilan_id?: number | null;
}): string {
  const type = String(row.type ?? "").trim();
  const owner = String(row.owner_email ?? "").trim().toLowerCase();
  const actor = String(row.actor_email ?? "").trim().toLowerCase();
  const sk = String(row.sohbet_key ?? "").trim();
  const ref = sk || `i:${row.ilan_id ?? 0}`;
  return `ins:${type}:${owner}:${actor}:${ref}`;
}

export async function claimPushSend(
  // deno-lint-ignore no-explicit-any
  admin: { from: (t: string) => any },
  opts: { bildirimId?: number; event?: string; dedupeKey?: string },
): Promise<"ok" | "duplicate"> {
  const key = (opts.dedupeKey ?? "").trim();
  if (key) {
    const { error } = await admin.from("push_dedupe").insert({
      dedupe_key: key,
    });
    if (error?.code === "23505") return "duplicate";
    if (error) console.error("push_dedupe", error);
  }
  const id = Number(opts.bildirimId ?? 0);
  if (id > 0 && !key.startsWith("upd:")) {
    const { error } = await admin.from("push_dispatch").insert({
      bildirim_id: id,
      event: opts.event || "PUSH",
    });
    if (error?.code === "23505") return "duplicate";
    if (error) console.error("push_dispatch", error);
  }
  return "ok";
}
