import { Module } from '@nestjs/common';
import { MainDbModule } from '../../infrastructure/databases/main-db/main-db.module';
import { ProjectionCardsRepository } from './repositories/projection-cards.repository';
import { ProjectionsService } from './services/projections.service';

@Module({
    imports: [MainDbModule],
    controllers: [],
    providers: [
        // services
        ProjectionsService,

        // repositories
        ProjectionCardsRepository,
    ],
    exports: [ProjectionsService],
})
export class ProjectionsModule {}
