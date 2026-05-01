import { ClassSerializerInterceptor, ValidationPipe, VersioningType } from '@nestjs/common';
import { NestFactory, Reflector } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import compression from 'compression';
import basicAuth from 'express-basic-auth';
import helmet from 'helmet';
import { AppModule } from './app.module';

async function bootstrap() {
    const app = await NestFactory.create(AppModule);

    app.enableCors({ origin: '*' });

    app.use(
        helmet({
            contentSecurityPolicy: {
                directives: {
                    defaultSrc: ["'self'"],
                    scriptSrc: ["'self'", 'https:', "'unsafe-inline'"],
                    scriptSrcElem: ["'self'", 'https:', "'unsafe-inline'"],
                    styleSrc: ["'self'", 'https:', "'unsafe-inline'"],
                    imgSrc: ["'self'", '', 'https:'],
                    fontSrc: ["'self'", 'https:', ''],
                    connectSrc: ["'self'", 'http://localhost:4040'],
                },
            },
        }),
    );
    app.use(compression());

    app.useGlobalInterceptors(
        new ClassSerializerInterceptor(app.get(Reflector), {
            excludeExtraneousValues: true, // respektuje @Expose
            enableImplicitConversion: true,
        }),
    );

    app.enableVersioning({
        type: VersioningType.HEADER,
        header: 'x-graphql-preview-version',
    });

    const config = new DocumentBuilder()
        .setTitle('GraphQL Preview API')
        .setDescription('API for GraphQL Preview Service')
        .setVersion('1.0')
        // .addBearerAuth(
        //     {
        //         type: 'http',
        //         scheme: 'bearer',
        //         bearerFormat: 'JWT',
        //         name: 'JWT',
        //         description: 'Enter JWT token',
        //         in: 'header',
        //     },
        //     'Cognito-Jwt-Auth',
        // )
        .build();

    const document = SwaggerModule.createDocument(app, config);

    const apiDocUser = process.env.API_DOC_USER;
    const apiDocPass = process.env.API_DOC_PASS;

    if (!apiDocUser || !apiDocPass) {
        throw new Error('API_DOC_USER and API_DOC_PASS environment variables must be defined');
    }

    app.use(
        '/api',
        basicAuth({
            users: { [apiDocUser]: apiDocPass },
            challenge: true,
        }),
    );

    SwaggerModule.setup('api', app, document, {
        customSiteTitle: 'GraphQL Preview API Documentation',
        customfavIcon: '/favicon.ico',
        swaggerOptions: {
            tagsSorter: 'alpha',
            operationsSorter: 'alpha',
            defaultModelsExpandDepth: -1,
            docExpansion: 'none',
        },
    });

    app.useGlobalPipes(
        new ValidationPipe({
            whitelist: true,
            transform: true,
            transformOptions: { enableImplicitConversion: true },
            forbidNonWhitelisted: true,
        }),
    );

    await app.listen(process.env.PORT ?? 4040);
}

bootstrap().catch(console.error);
