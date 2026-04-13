// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_cache.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetActivityCacheCollection on Isar {
  IsarCollection<ActivityCache> get activityCaches => this.collection();
}

const ActivityCacheSchema = CollectionSchema(
  name: r'ActivityCache',
  id: 8476228503264501002,
  properties: {
    r'date': PropertySchema(
      id: 0,
      name: r'date',
      type: IsarType.dateTime,
    ),
    r'isAsleep': PropertySchema(
      id: 1,
      name: r'isAsleep',
      type: IsarType.bool,
    ),
    r'steps': PropertySchema(
      id: 2,
      name: r'steps',
      type: IsarType.long,
    ),
    r'workoutMinutes': PropertySchema(
      id: 3,
      name: r'workoutMinutes',
      type: IsarType.long,
    )
  },
  estimateSize: _activityCacheEstimateSize,
  serialize: _activityCacheSerialize,
  deserialize: _activityCacheDeserialize,
  deserializeProp: _activityCacheDeserializeProp,
  idName: r'id',
  indexes: {
    r'date': IndexSchema(
      id: -7552997827385218417,
      name: r'date',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'date',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _activityCacheGetId,
  getLinks: _activityCacheGetLinks,
  attach: _activityCacheAttach,
  version: '3.1.0+1',
);

int _activityCacheEstimateSize(
  ActivityCache object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _activityCacheSerialize(
  ActivityCache object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.date);
  writer.writeBool(offsets[1], object.isAsleep);
  writer.writeLong(offsets[2], object.steps);
  writer.writeLong(offsets[3], object.workoutMinutes);
}

ActivityCache _activityCacheDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ActivityCache(
    date: reader.readDateTimeOrNull(offsets[0]),
    isAsleep: reader.readBoolOrNull(offsets[1]),
    steps: reader.readLongOrNull(offsets[2]),
    workoutMinutes: reader.readLongOrNull(offsets[3]),
  );
  object.id = id;
  return object;
}

P _activityCacheDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readBoolOrNull(offset)) as P;
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _activityCacheGetId(ActivityCache object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _activityCacheGetLinks(ActivityCache object) {
  return [];
}

void _activityCacheAttach(
    IsarCollection<dynamic> col, Id id, ActivityCache object) {
  object.id = id;
}

extension ActivityCacheByIndex on IsarCollection<ActivityCache> {
  Future<ActivityCache?> getByDate(DateTime? date) {
    return getByIndex(r'date', [date]);
  }

  ActivityCache? getByDateSync(DateTime? date) {
    return getByIndexSync(r'date', [date]);
  }

  Future<bool> deleteByDate(DateTime? date) {
    return deleteByIndex(r'date', [date]);
  }

  bool deleteByDateSync(DateTime? date) {
    return deleteByIndexSync(r'date', [date]);
  }

  Future<List<ActivityCache?>> getAllByDate(List<DateTime?> dateValues) {
    final values = dateValues.map((e) => [e]).toList();
    return getAllByIndex(r'date', values);
  }

  List<ActivityCache?> getAllByDateSync(List<DateTime?> dateValues) {
    final values = dateValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'date', values);
  }

  Future<int> deleteAllByDate(List<DateTime?> dateValues) {
    final values = dateValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'date', values);
  }

  int deleteAllByDateSync(List<DateTime?> dateValues) {
    final values = dateValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'date', values);
  }

  Future<Id> putByDate(ActivityCache object) {
    return putByIndex(r'date', object);
  }

  Id putByDateSync(ActivityCache object, {bool saveLinks = true}) {
    return putByIndexSync(r'date', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByDate(List<ActivityCache> objects) {
    return putAllByIndex(r'date', objects);
  }

  List<Id> putAllByDateSync(List<ActivityCache> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'date', objects, saveLinks: saveLinks);
  }
}

extension ActivityCacheQueryWhereSort
    on QueryBuilder<ActivityCache, ActivityCache, QWhere> {
  QueryBuilder<ActivityCache, ActivityCache, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterWhere> anyDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'date'),
      );
    });
  }
}

extension ActivityCacheQueryWhere
    on QueryBuilder<ActivityCache, ActivityCache, QWhereClause> {
  QueryBuilder<ActivityCache, ActivityCache, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterWhereClause> dateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'date',
        value: [null],
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterWhereClause>
      dateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'date',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterWhereClause> dateEqualTo(
      DateTime? date) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'date',
        value: [date],
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterWhereClause> dateNotEqualTo(
      DateTime? date) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'date',
              lower: [],
              upper: [date],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'date',
              lower: [date],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'date',
              lower: [date],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'date',
              lower: [],
              upper: [date],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterWhereClause> dateGreaterThan(
    DateTime? date, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'date',
        lower: [date],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterWhereClause> dateLessThan(
    DateTime? date, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'date',
        lower: [],
        upper: [date],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterWhereClause> dateBetween(
    DateTime? lowerDate,
    DateTime? upperDate, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'date',
        lower: [lowerDate],
        includeLower: includeLower,
        upper: [upperDate],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ActivityCacheQueryFilter
    on QueryBuilder<ActivityCache, ActivityCache, QFilterCondition> {
  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      dateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'date',
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      dateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'date',
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition> dateEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'date',
        value: value,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      dateGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'date',
        value: value,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      dateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'date',
        value: value,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition> dateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'date',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      isAsleepIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'isAsleep',
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      isAsleepIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'isAsleep',
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      isAsleepEqualTo(bool? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isAsleep',
        value: value,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      stepsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'steps',
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      stepsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'steps',
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      stepsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'steps',
        value: value,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      stepsGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'steps',
        value: value,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      stepsLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'steps',
        value: value,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      stepsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'steps',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      workoutMinutesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workoutMinutes',
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      workoutMinutesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workoutMinutes',
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      workoutMinutesEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workoutMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      workoutMinutesGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workoutMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      workoutMinutesLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workoutMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterFilterCondition>
      workoutMinutesBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workoutMinutes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ActivityCacheQueryObject
    on QueryBuilder<ActivityCache, ActivityCache, QFilterCondition> {}

extension ActivityCacheQueryLinks
    on QueryBuilder<ActivityCache, ActivityCache, QFilterCondition> {}

extension ActivityCacheQuerySortBy
    on QueryBuilder<ActivityCache, ActivityCache, QSortBy> {
  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy> sortByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy> sortByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy> sortByIsAsleep() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAsleep', Sort.asc);
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy>
      sortByIsAsleepDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAsleep', Sort.desc);
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy> sortBySteps() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'steps', Sort.asc);
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy> sortByStepsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'steps', Sort.desc);
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy>
      sortByWorkoutMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workoutMinutes', Sort.asc);
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy>
      sortByWorkoutMinutesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workoutMinutes', Sort.desc);
    });
  }
}

extension ActivityCacheQuerySortThenBy
    on QueryBuilder<ActivityCache, ActivityCache, QSortThenBy> {
  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy> thenByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy> thenByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy> thenByIsAsleep() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAsleep', Sort.asc);
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy>
      thenByIsAsleepDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAsleep', Sort.desc);
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy> thenBySteps() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'steps', Sort.asc);
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy> thenByStepsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'steps', Sort.desc);
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy>
      thenByWorkoutMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workoutMinutes', Sort.asc);
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QAfterSortBy>
      thenByWorkoutMinutesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workoutMinutes', Sort.desc);
    });
  }
}

extension ActivityCacheQueryWhereDistinct
    on QueryBuilder<ActivityCache, ActivityCache, QDistinct> {
  QueryBuilder<ActivityCache, ActivityCache, QDistinct> distinctByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'date');
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QDistinct> distinctByIsAsleep() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isAsleep');
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QDistinct> distinctBySteps() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'steps');
    });
  }

  QueryBuilder<ActivityCache, ActivityCache, QDistinct>
      distinctByWorkoutMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workoutMinutes');
    });
  }
}

extension ActivityCacheQueryProperty
    on QueryBuilder<ActivityCache, ActivityCache, QQueryProperty> {
  QueryBuilder<ActivityCache, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ActivityCache, DateTime?, QQueryOperations> dateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'date');
    });
  }

  QueryBuilder<ActivityCache, bool?, QQueryOperations> isAsleepProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isAsleep');
    });
  }

  QueryBuilder<ActivityCache, int?, QQueryOperations> stepsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'steps');
    });
  }

  QueryBuilder<ActivityCache, int?, QQueryOperations> workoutMinutesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workoutMinutes');
    });
  }
}
