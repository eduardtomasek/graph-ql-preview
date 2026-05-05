import { Injectable } from '@nestjs/common';
import { CardModel } from '../../cards/models/card.model';
import { CardsCacheRedisRepository } from '../repositories/cards.cache.redis.repository';

@Injectable()
export class CardsCacheService {
    constructor(private readonly cardsCacheRedisRepository: CardsCacheRedisRepository) {}

    async cacheCardsBySlugs(cards: CardModel[]) {
        await this.cardsCacheRedisRepository.setCardsBySlug(cards);
    }

    async cacheCardBySlug(slug: string, data: CardModel) {
        await this.cardsCacheRedisRepository.setCardBySlug(slug, data);
    }

    async getCardBySlug(slug: string): Promise<CardModel | null> {
        return await this.cardsCacheRedisRepository.getCardBySlug(slug);
    }
}
