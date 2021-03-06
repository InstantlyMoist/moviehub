import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:moviehub/models/account.dart';
import 'package:moviehub/models/genres.dart';
import 'package:moviehub/models/list.dart';
import 'package:moviehub/models/movie.dart';
import 'package:moviehub/models/statistics.dart';
import 'package:moviehub/utils/converter_utils.dart';
import 'package:moviehub/utils/data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class NetworkUtils {
  static final String baseUrl = "https://api.themoviedb.org/3/";

  // Builds a url according to the shared preferences
  static Future<String> urlBuilder(URLBuilderType type,
      {String query, int listId}) async {
    await DotEnv().load(".env");

    switch (type) {
      case URLBuilderType.DISCOVER:
        SharedPreferences preferences = await SharedPreferences.getInstance();
        List<String> filters = preferences.getStringList("filters");
        List<String> headers = List();
        headers.add(DotEnv().env["apiKey"]);

        String sort = preferences.getString("sort");

        if (filters != null) headers.addAll(filters);
        if (sort != null) headers.add("sort_by=" + sort);

        return "${baseUrl}discover/movie?api_key=${headers.join("&")}";
      case URLBuilderType.SEARCH:
        if (query != null) {
          return "${baseUrl}search/movie?api_key=${DotEnv().env["apiKey"]}&query=$query";
        }
        throw Exception('Querystring is required');
      case URLBuilderType.LIST:
        if (listId != null) {
          return "${baseUrl}list/$listId?api_key=${DotEnv().env["apiKey"]}";
        }
        throw Exception('ListId is required');
    }
  }

  // Returns the movies parsed into objects of the Movie class
  static Future<List<MovieCardModel>> fetchMovies(
      String url, URLBuilderType type) async {
    List<MovieCardModel> movies = new List();

    final response = await http.get(url);

    dynamic body = response.body;

    List<dynamic> movieJson = type == URLBuilderType.LIST
        ? json.decode(body)['items']
        : json.decode(body)['results'];

    if (response.statusCode == 200 && movieJson != null) {
      for (Map<String, dynamic> movie in movieJson) {
        movies.add(Converter.convertMovieCard(movie));
      }

      return movies;
    } else {
      throw Exception('Failed to load movies');
    }
  }

  static Future<MovieDetailsModel> fetchMovieDetails(int movieId) async {
    await DotEnv().load(".env");
    String apiKey = DotEnv().env["apiKey"];

    final detailsResponse =
        await http.get("${baseUrl}movie/$movieId?api_key=$apiKey");
    final creditsResponse =
        await http.get("${baseUrl}movie/$movieId/credits?api_key=$apiKey");
    final videoResponse =
        await http.get("${baseUrl}movie/$movieId/videos?api_key=$apiKey");

    Map<String, dynamic> movieJson = json.decode(detailsResponse.body);
    Map<String, dynamic> creditsJson = json.decode(creditsResponse.body);
    Map<String, dynamic> videoJson = jsonDecode(videoResponse.body);

    if (detailsResponse.statusCode != 200 ||
        creditsResponse.statusCode != 200 ||
        videoResponse.statusCode != 200 ||
        movieJson == null ||
        creditsJson == null ||
        videoJson == null) throw Exception('Failed to load movie');

    return Converter.convertMovieDetails(movieJson, creditsJson, videoJson);
  }

  static Future<bool> postRating(
      int movieId, int rating, String sessionId) async {
    await DotEnv().load(".env");
    String apiKey = DotEnv().env["apiKey"];

    return http
        .post(
            "${baseUrl}movie/$movieId/rating?api_key=$apiKey&session_id=$sessionId",
            headers: {"Content-type": "application/json"},
            body: jsonEncode({"value": rating}))
        .then((response) => response.statusCode == 200);
  }

  static Future<bool> deleteRating(int movieId, String sessionId) async {
    await DotEnv().load(".env");
    String apiKey = DotEnv().env["apiKey"];

    return http
        .delete(
            "${baseUrl}movie/$movieId/rating?api_key=$apiKey&session_id=$sessionId")
        .then((response) => response.statusCode == 200);
  }

  static Future<ListCardModel> createList(
      String name, String description, String sessionId) async {
    await DotEnv().load(".env");
    String apiKey = DotEnv().env["apiKey"];

    final response = await http.post(
        "${baseUrl}list?api_key=$apiKey&session_id=$sessionId",
        headers: {"Content-type": "application/json"},
        body: jsonEncode(
            {"name": name, "description": description, "language": "en"}));

    Map<String, dynamic> json = jsonDecode(response.body);

    if (response.statusCode == 201 && json != null) {
      return ListCardModel(json["list_id"], 0, name, description);
    } else
      throw Exception("Failed to create the list");
  }

  static Future<bool> deleteList(int listId, String sessionId) async {
    await DotEnv().load(".env");
    String apiKey = DotEnv().env["apiKey"];

    return http
        .delete("${baseUrl}list/$listId?api_key=$apiKey&session_id=$sessionId")
        .then((response) =>
            response.statusCode == 500); // TODO: why internal server error?
  }

  static Future<bool> clearList(int listId, String sessionId) async {
    await DotEnv().load(".env");
    String apiKey = DotEnv().env["apiKey"];
    return http
        .post(
            "${baseUrl}list/$listId?api_key=$apiKey&session_id=$sessionId&confirm=true")
        .then((response) => response.statusCode == 201);
  }

  static Future<bool> addMovieToList(
      int listId, int movieId, String sessionId) async {
    await DotEnv().load(".env");
    String apiKey = DotEnv().env["apiKey"];

    return http
        .post(
            "${baseUrl}list/$listId/add_item?api_key=$apiKey&session_id=$sessionId",
            headers: {"Content-type": "application/json"},
            body: json.encode({"media_id": movieId}))
        .then((response) => response.statusCode == 201);
  }

  static Future<bool> removeMovieFromList(
      int listId, int movieId, String sessionId) async {
    await DotEnv().load(".env");
    String apiKey = DotEnv().env["apiKey"];

    return await http
        .post(
            "${baseUrl}list/$listId/remove_item?api_key=$apiKey&session_id=$sessionId",
            headers: {"Content-type": "application/json"},
            body: json.encode({"media_id": movieId}))
        .then((response) => response.statusCode == 200);
  }

  static Future<ListDetailsModel> fetchList(int listId) async {
    List<MovieCardModel> movies = List();

    await DotEnv().load(".env");
    String apiKey = DotEnv().env["apiKey"];

    final response = await http.get("${baseUrl}list/$listId?api_key=$apiKey");

    Map<String, dynamic> listJson = jsonDecode(response.body);

    if (response.statusCode == 200 && listJson != null) {
      for (Map<String, dynamic> movieJson in listJson["items"]) {
        movies.add(Converter.convertMovieCard(movieJson));
      }

      return ListDetailsModel(num.parse(listJson["id"]), listJson["name"],
          listJson["description"], movies);
    } else
      throw Exception("Couldn't get the details of this list");
  }

  static Future<String> fetchRequestURL() async {
    await DotEnv().load(".env");
    String apiKey = DotEnv().env["apiKey"];

    final response =
        await http.get("${baseUrl}authentication/token/new?api_key=$apiKey");

    Map<String, dynamic> responseJson = jsonDecode(response.body);

    if (response.statusCode == 200 && responseJson != null) {
      await SharedPreferences.getInstance().then((preferences) => preferences
          .setString("request_token", responseJson["request_token"]));
      return "https://www.themoviedb.org/authenticate/${responseJson["request_token"]}";
    } else {
      throw Exception('Failed to get request token');
    }
  }

  static Future<Account> loginComplete() async {
    await DotEnv().load(".env");
    String apiKey = DotEnv().env["apiKey"];

    String requestToken = await SharedPreferences.getInstance()
        .then((preferences) => preferences.getString("request_token"));

    final sessionResponse = await http.post(
        "${baseUrl}authentication/session/new?api_key=$apiKey",
        headers: {"Content-type": "application/json"},
        body: jsonEncode({"request_token": requestToken}));

    if (sessionResponse.statusCode == 200) {
      dynamic json = jsonDecode(sessionResponse.body);
      String sessionId = json["session_id"];

      return fetchAccount(sessionId);
    } else {
      throw Exception('Failed to get session token');
    }
  }

  static Future<Account> fetchAccount(String sessionId) async {
    await DotEnv().load(".env");
    String apiKey = DotEnv().env["apiKey"];

    final response = await http
        .get("${baseUrl}account?api_key=$apiKey&session_id=$sessionId");

    Map<String, dynamic> accountJson = jsonDecode(response.body);

    if (response.statusCode == 200 && accountJson != null) {
      accountJson.putIfAbsent("session_id", () => sessionId);
      return Converter.convertAccount(accountJson);
    } else {
      throw Exception('Failed to get account details');
    }
  }

  static Future<List<ListCardModel>> fetchLists() async {
    List<ListCardModel> lists = List();

    await DotEnv().load(".env");
    String apiKey = DotEnv().env["apiKey"];

    Account account = await Account.fromJson();

    if (account == null) throw Exception("You must first log in");

    final response = await http.get(
        "${baseUrl}account/${account.accountId}/lists?api_key=$apiKey&session_id=${account.sessionId}");

    Map<String, dynamic> json = jsonDecode(response.body);

    if (response.statusCode == 200 && json != null) {
      for (Map<String, dynamic> listCardJson in json["results"]) {
        lists.add(Converter.convertListCard(listCardJson));
      }
    }

    return lists;
  }

  static Future<String> fetchIMDBURL(int movieId) async {
    await DotEnv().load(".env");
    String apiKey = DotEnv().env["apiKey"];

    final response =
        await http.get("${baseUrl}movie/$movieId/external_ids?api_key=$apiKey");

    Map<String, dynamic> json = jsonDecode(response.body);

    if (response.statusCode == 200 && json != null) {
      return json["imdb_id"] != null
          ? "https://www.imdb.com/title/${json["imdb_id"]}/?ref_=hm_hp_cap_pri_1"
          : null;
    } else
      throw Exception('Failed to get external IMDB id');
  }

  static Future<StatisticsModel> fetchStatistics() async {
    Map<int, int> genreCount = Map();
    Map<ListDetailsModel, double> listRating = Map();
    Map<int, double> movieRatingsMap = Map();

    List<Future<ListDetailsModel>> futuresList = List();

    await fetchLists().then((lists) => {
          lists.forEach(
              (listModel) => {futuresList.add(fetchList(listModel.id))})
        });

    await Future.wait(futuresList, eagerError: true).then(
        (listDetailsModelList) => listDetailsModelList.forEach(
            (listDetailsModel) =>
                listDetailsModel.items.forEach((movieCard) => {
                      movieCard.movieGenres.forEach((genre) => genreCount
                          .update(genre.id, (currentValue) => ++currentValue,
                              ifAbsent: () => 1)),
                      listRating.update(
                          listDetailsModel,
                          (currentRating) =>
                              currentRating + movieCard.movieRating,
                          ifAbsent: () => movieCard.movieRating),
                      movieRatingsMap.update(
                          movieCard.movieId, (currentValue) => currentValue,
                          ifAbsent: () => movieCard.movieRating)
                    })));

    List<MapEntry<int, int>> genreMapEntries =
        genreCount.entries.toList(growable: false);
    genreMapEntries.sort((one, other) => other.value.compareTo(one.value));
    List<Genre> topGenres = genreMapEntries
        .map((mapEntry) => Genre(mapEntry.key, Data.genres[mapEntry.key]))
        .toList();

    List<MapEntry<ListDetailsModel, double>> listRatingMapEntries =
        listRating.entries.toList(growable: false);
    listRatingMapEntries.sort((one, other) => other.value.compareTo(one.value));

    List<double> movieRatingsList =
        movieRatingsMap.values.toList(growable: false);

    double averageMovieRating = movieRatingsList.isNotEmpty
        ? num.parse(((movieRatingsList.reduce((one, other) => one + other) /
                    movieRatingsList.length) /
                2)
            .toStringAsFixed(1))
        : 0;

    return StatisticsModel(
        topGenres,
        listRatingMapEntries.isNotEmpty
            ? listRatingMapEntries.first.key.name
            : "",
        listRatingMapEntries.isNotEmpty
            ? num.parse(
                (listRatingMapEntries.first.value / 2).toStringAsFixed(1))
            : 0,
        averageMovieRating);
  }
}
