import '../../domain/entities/forum_disease.dart';
import '../../domain/entities/forum_topic.dart';
import '../../domain/repositories/forum_repository.dart';
import '../datasources/forum_remote_datasource.dart';

class ForumRepositoryImpl implements ForumRepository {
  ForumRepositoryImpl({ForumRemoteDataSource? remote})
      : _remote = remote ?? ForumRemoteDataSource();

  final ForumRemoteDataSource _remote;

  @override
  Future<List<ForumDisease>> fetchDiseases() => _remote.fetchDiseases();

  @override
  Future<List<ForumSubCategory>> fetchSubCategories({String? diseaseId}) =>
      _remote.fetchSubCategories(diseaseId: diseaseId);

  @override
  Future<ForumTopicsPage> fetchTopics({
    required ForumFilterParams filter,
    required int page,
    int pageSize = 20,
  }) =>
      _remote.fetchTopics(filter: filter, page: page, pageSize: pageSize);

  @override
  Future<void> incrementViews(int topicId) => _remote.incrementViews(topicId);
}
