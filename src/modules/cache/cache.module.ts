import { Module } from '@nestjs/common';
import { MainRedisModule } from '../../infrastructure/databases/main-redis/main-redis.module';
import { CardsCacheRedisRepository } from './repositories/cards.cache.redis.repository';
import { CacheService } from './services/cache.service';
import { CardsCacheService } from './services/cards.cache.service';

@Module({
    imports: [MainRedisModule],
    providers: [
        // services
        CacheService,
        CardsCacheService,

        // repositories
        CardsCacheRedisRepository,
    ],
    exports: [CacheService, CardsCacheService],
})
export class CacheModule {}
