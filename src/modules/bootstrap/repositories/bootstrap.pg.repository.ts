import { Inject, Injectable } from '@nestjs/common';
import * as pgp from 'pg-promise';
import { MAIN_PG_CONNECTION } from '../../../libs/core/constants';

@Injectable()
export class BootstrapPgRepository {
    constructor(@Inject(MAIN_PG_CONNECTION) private readonly db: pgp.IDatabase<any>) {}

    async bootstrapDatabase(sql: string): Promise<void> {
        try {
            await this.db.none(sql);
        } catch (error) {
            console.error('Error bootstrapping the database:', error);
            throw new Error('Failed to bootstrap the database.');
        }
    }
}
