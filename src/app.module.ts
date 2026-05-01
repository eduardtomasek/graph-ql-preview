import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { GraphQLModule } from '@nestjs/graphql';
import { AppController } from './app.controller';
import { AppResolver } from './app.resolver';
import { AppService } from './app.service';
import { MainDbModule } from './infrastructure/databases/main-db/main-db.module';

@Module({
    imports: [
        ConfigModule.forRoot({
            isGlobal: true,
            envFilePath: ['.env'],
        }),
        GraphQLModule.forRoot<ApolloDriverConfig>({
            driver: ApolloDriver,
            autoSchemaFile: true,
            playground: false,
            graphiql: true,
        }),
        MainDbModule,
    ],
    controllers: [AppController],
    providers: [
        // services
        AppService,

        // resolvers
        AppResolver,
    ],
})
export class AppModule {}
