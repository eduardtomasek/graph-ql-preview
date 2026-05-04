import { Field, Float, Int, ObjectType } from '@nestjs/graphql';

@ObjectType()
export class CardListItemModel {
    @Field()
    uuid: string;

    @Field()
    name: string;

    @Field()
    slug: string;

    @Field()
    typeCode: string;

    @Field()
    factionCode: string;

    @Field()
    rarityCode: string;

    @Field()
    setCode: string;

    @Field(() => Int)
    cost: number;

    @Field(() => Int, { nullable: true })
    attack?: number;

    @Field(() => Int, { nullable: true })
    defense?: number;

    @Field(() => Int, { nullable: true })
    health?: number;

    @Field(() => Float)
    powerScore: number;

    @Field(() => [String])
    tags: string[];
}
