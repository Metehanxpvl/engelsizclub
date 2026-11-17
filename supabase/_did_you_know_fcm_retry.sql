select net.http_post(
  url := 'https://qycrkqwqrysypvqaipqn.supabase.co/functions/v1/broadcast-push',
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer sb_publishable_N7UfnXDF97YsuDTsFTq9zQ_lhnNtMgF',
    'apikey', 'sb_publishable_N7UfnXDF97YsuDTsFTq9zQ_lhnNtMgF'
  ),
  body := jsonb_build_object(
    'source', 'db',
    'table', 'duyurular',
    'record', jsonb_build_object('id', 87)
  ),
  timeout_milliseconds := 20000
);
