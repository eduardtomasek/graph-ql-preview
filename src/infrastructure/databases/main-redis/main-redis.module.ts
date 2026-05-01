// redis.module.ts
import { Global, Logger, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient } from 'redis';
import { redisConnection } from '../../../libs/shared-utils/functions/redis-connection-url';

function withTimeout<T>(p: Promise<T>, ms: number, label: string): Promise<T> {
    return Promise.race([
        p,
        new Promise<T>((_, reject) => setTimeout(() => reject(new Error(`${label} timed out after ${ms}ms`)), ms)),
    ]);
}

@Global()
@Module({
    providers: [
        {
            provide: 'REDIS_CLIENT',
            useFactory: async (configService: ConfigService) => {
                const logger = new Logger('REDIS_CLIENT');
                const host = configService.getOrThrow<string>('REDIS_HOST');
                const port = configService.get<number>('REDIS_PORT') ?? 6379;

                const { url } = redisConnection(host, Number(port));
                logger.log(`Creating client: ${url}`);

                const client = createClient({
                    url,
                    socket: {
                        connectTimeout: 5000,
                        reconnectStrategy: (retries) => {
                            if (retries > 5) {
                                return new Error('Max retries reached');
                            }
                            return Math.min(retries * 100, 3000); // Zkuste znovu za 100ms, 200ms, 400ms, až do 3 sekund
                        },
                    },
                });

                client.on('error', (e: Error) => logger.error(e.message));
                client.on('connect', () => logger.log('Socket connected'));
                client.on('ready', () => logger.log('Ready'));

                logger.log('Connecting...');
                await withTimeout(client.connect(), 7000, 'redis.connect');
                logger.log('Connected OK');

                return client;
            },
            inject: [ConfigService],
        },
    ],
    exports: ['REDIS_CLIENT'],
})
export class ProductionRedisModule {}
