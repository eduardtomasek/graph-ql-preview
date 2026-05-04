import { Field, Float, Int, ObjectType } from '@nestjs/graphql';

@ObjectType()
export class CardStatsModel {
    @Field(() => Int, { nullable: true })
    attack?: number;

    @Field(() => Int, { nullable: true })
    defense?: number;

    @Field(() => Int, { nullable: true })
    health?: number;

    @Field(() => Int, { nullable: true })
    speed?: number;

    @Field(() => Int, { nullable: true })
    range?: number;

    @Field(() => Int, { nullable: true })
    armor?: number;
}

@ObjectType()
export class CardTagModel {
    @Field()
    code: string;

    @Field()
    name: string;
}

@ObjectType()
export class CardAbilityModel {
    @Field()
    code: string;

    @Field()
    name: string;

    @Field()
    trigger: string;

    @Field()
    effect: string;

    @Field()
    description: string;
}

@ObjectType()
export class CardModel {
    @Field()
    uuid: string;

    @Field()
    code: string;

    @Field()
    name: string;

    @Field()
    slug: string;

    @Field()
    typeCode: string;

    @Field()
    typeName: string;

    @Field()
    factionCode: string;

    @Field()
    factionName: string;

    @Field()
    rarityCode: string;

    @Field()
    rarityName: string;

    @Field(() => Int)
    cost: number;

    @Field(() => CardStatsModel, { nullable: true })
    stats?: CardStatsModel;

    @Field(() => [CardTagModel])
    tags: CardTagModel[];

    @Field(() => [CardAbilityModel])
    abilities: CardAbilityModel[];

    @Field({ nullable: true })
    rulesText?: string;

    @Field({ nullable: true })
    loreText?: string;

    @Field({ nullable: true })
    imageUrl?: string;

    @Field(() => Float)
    powerScore: number;

    @Field()
    isCollectible: boolean;

    @Field()
    isActive: boolean;
}
