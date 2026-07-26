-- Реализация UUID v7 на чистом SQL
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE OR REPLACE FUNCTION uuidv7()
RETURNS UUID
AS $$
DECLARE
    timestamp_ms BIGINT;
    uuid_bytes BYTEA;
    timestamp_hex TEXT;
    rand_hex TEXT;
BEGIN
    -- Текущее время в миллисекундах с эпохи Unix
    timestamp_ms := (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT;

    -- Собираем UUID v7 в hex-формате:
    -- 1) 8 hex символов (32 бита) времени (старшие биты)
    -- 2) 4 hex символа (16 бит) времени (средние биты)
    -- 3) 4 hex символа (12 бит времени + версия 7 в старших 4 битах)
    -- 4) 4 hex символа (вариант 10xx + 12 бит случайных)
    -- 5) 12 hex символов (случайные)
    timestamp_hex :=
        lpad(to_hex((timestamp_ms >> 16) & x'FFFFFFFF'::BIGINT), 8, '0') ||
        lpad(to_hex((timestamp_ms >> 12) & x'FFFF'::BIGINT), 4, '0') ||
        lpad(to_hex(((timestamp_ms >> 0) & x'FFF'::BIGINT) | x'7000'::BIGINT), 4, '0');

    -- Генерируем 10 байт случайных данных (80 бит)
    rand_hex := encode(gen_random_bytes(10), 'hex');

    -- Склеиваем всё в UUID: первые 8 символов временной части, затем вариант и случайные
    RETURN (timestamp_hex ||
            substr(rand_hex, 1, 4) ||
            substr(rand_hex, 5, 12))::UUID;
END
$$ LANGUAGE plpgsql VOLATILE;


-----------------------------------

-- Тут создается функция UUID в postgresql, UUIDv7 выбрал потому что в нем первые символы обозначают дату и поэтому новые записи 
-- появляются в конце и не ломают индексы (меньше нагрузка)

--------------------------------------
