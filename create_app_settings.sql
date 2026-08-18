CREATE TABLE IF NOT EXISTS public.app_settings (
    id TEXT PRIMARY KEY,
    season_name TEXT NOT NULL,
    season_end TIMESTAMP WITH TIME ZONE
);

INSERT INTO public.app_settings (id, season_name, season_end)
VALUES ('default', 'Season 1', (NOW() + INTERVAL '30 days'))
ON CONFLICT (id) DO NOTHING;
