import { Injectable } from '@nestjs/common';
import { CardsProjectionsPgRepository } from '../repositories/cards.projections.pg.repository';

@Injectable()
export class ProjectionsService {
    constructor(private readonly projectionCardsRepository: CardsProjectionsPgRepository) {}

    async findBySlug(slug: string) {
        return this.projectionCardsRepository.findBySlug(slug);
    }

    async findBySlugs(slugs: string[]) {
        return this.projectionCardsRepository.findBySlugs(slugs);
    }
}
