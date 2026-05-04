import { Module } from '@nestjs/common';
import { MainDbModule } from '../../infrastructure/databases/main-db/main-db.module';
import { CardsProjectionsBuilder } from './builders/cards/cards.projections.builder';
import { CardsBuilderProjectionsPgRepository } from './repositories/cards-builder.projections.pg.repository';
import { CardsProjectionsPgRepository } from './repositories/cards.projections.pg.repository';
import { CardsBuilderProjectionsService } from './services/cards-builder.projections.service';
import { ProjectionsService } from './services/projections.service';

@Module({
    imports: [MainDbModule],
    controllers: [],
    providers: [
        // services
        ProjectionsService,
        CardsBuilderProjectionsService,

        // repositories
        CardsProjectionsPgRepository,
        CardsBuilderProjectionsPgRepository,

        // builders
        CardsProjectionsBuilder,
    ],
    exports: [ProjectionsService, CardsBuilderProjectionsService],
})
export class ProjectionsModule {}
