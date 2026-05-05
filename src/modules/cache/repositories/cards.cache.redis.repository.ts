import { Inject, Injectable } from '@nestjs/common';
import * as redis_1 from 'redis';
import { MAIN_REDIS_CONNECTION } from '../../../libs/core/constants';
import { CardModel } from '../../cards/models/card.model';

@Injectable()
export class CardsCacheRedisRepository {
    constructor(@Inject(MAIN_REDIS_CONNECTION) private readonly redisClient: redis_1.RedisClientType) {}

    async setCardBySlug(slug: string, data: CardModel) {
        await this.redisClient.set(`card-slug:${slug}:v1`, JSON.stringify(data));
    }

    async setCardsBySlug(cards: CardModel[]): Promise<void> {
        if (cards.length === 0) return;

        const pipeline = this.redisClient.multi();
        for (const card of cards) {
            pipeline.set(`card-slug:${card.slug}:v1`, JSON.stringify(card));
        }
        await pipeline.exec();
    }

    async getCardBySlug(slug: string): Promise<CardModel | null> {
        const data = await this.redisClient.get(`card-slug:${slug}:v1`);
        if (!data) {
            return null;
        }

        return JSON.parse(data) as CardModel;
    }
}
