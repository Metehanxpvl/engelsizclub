import '../entities/forum_disease.dart';
import '../entities/forum_topic.dart';

abstract class ForumRepository {
  Future<List<ForumDisease>> fetchDiseases();

  Future<List<ForumSubCategory>> fetchSubCategories({String? diseaseId});

  Future<ForumTopicsPage> fetchTopics({
    required ForumFilterParams filter,
    required int page,
    int pageSize = 20,
  });

  Future<void> incrementViews(int topicId);
}
