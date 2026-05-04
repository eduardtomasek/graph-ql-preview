import { Injectable } from '@nestjs/common';
import { ProjectionCardsRepository } from '../repositories/projection-cards.repository';

@Injectable()
export class ProjectionsService {
    constructor(private readonly projectionCardsRepository: ProjectionCardsRepository) {}

    async findBySlug(slug: string) {
        return this.projectionCardsRepository.findBySlug(slug);
    }
}
