import { Injectable } from '@nestjs/common';
import { CardsMapper } from '../mappers/cards.mapper';
import { CardModel } from '../models/card.model';
import { CardsPgRepository } from '../repositories/cards.pg.repository';

@Injectable()
export class CardsService {
    constructor(
        private readonly cardsPgRepository: CardsPgRepository,
        private readonly cardsMapper: CardsMapper,
    ) {}

    async getCardBySlug(slug: string): Promise<CardModel | null> {
        const cardRow = await this.cardsPgRepository.findCardBySlug(slug);

        if (!cardRow) {
            return null;
        }

        return this.cardsMapper.cardRowToCardModel(cardRow);
    }
}
