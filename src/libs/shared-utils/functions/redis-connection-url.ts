export interface RedisConnectionConfig {
    url: string;
    tls: boolean;
}

export function redisConnection(redisHost: string, redisPort: number): RedisConnectionConfig {
    const host = redisHost;
    const port = redisPort ?? 6379;

    if (!host) {
        throw new Error('REDIS_HOST is not defined');
    }

    // výchozí chování:
    // - produkce = TLS
    // - lokál = bez TLS
    const tls =
        process.env.REDIS_TLS === '1' || process.env.REDIS_TLS === 'true' || process.env.NODE_ENV === 'production';

    const protocol = tls ? 'rediss' : 'redis';
    const url = `${protocol}://${host}:${port}`;

    return { url, tls };
}
