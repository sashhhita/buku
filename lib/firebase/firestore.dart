import 'dart:math';

import 'package:buku/main_objects/author.dart';
import 'package:buku/main_objects/book.dart';
import 'package:buku/main_objects/book_comment.dart';
import 'package:buku/main_objects/mini_author.dart';
import 'package:buku/main_objects/mini_book.dart';
import 'package:buku/main_objects/mini_user.dart';
import 'package:buku/main_objects/publication.dart';
import 'package:buku/main_objects/structs/bk_tree.dart';
import 'package:buku/main_objects/structs/queue.dart';
import 'package:buku/main_objects/structs/heap.dart';
import 'package:buku/main_objects/user.dart';
import 'package:buku/search_engine/search.dart';
import 'package:buku/theme/current_theme.dart';
import 'package:buku/utilities/format_string.dart';
import 'package:buku/utilities/sort.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class Firestore {
  static final String nickname = 'nickname';
  static final String theme = 'theme';
  static final String name = 'name';
  static final String biography = 'desc';
  static final String userImgPath = 'image_path';
  static final String tags = 'tags';
  static final String favoriteBooks = 'favorite_books';
  static final String openHistory = 'open_history';
  static final String followers = 'followers';
  static final String following = 'following';
  static final String favoriteAuthors = 'favorite_authors';

  FirebaseFirestore store;

  Firestore() {
    store = FirebaseFirestore.instance;
  }

  //GETTERS////////////////////////////////////////////////////////////////////////////////////

  // users methods ----------------------------------------------------------------------------

  void createUser(String uid, String nickName) async {
    await store
        .collection('users')
        .doc(uid)
        .set({'nickname': nickName})
        .then((value) => print("user added"))
        .catchError((error) =>
            throw Exception('there´s a problem with the user: Not created'));
  }

  void storeMainData(String uid, String theme, String name, String desc,
      String userImg, List<String> tags) async {
    await store.collection('users').doc(uid).update({
      'theme': theme,
      'name': name,
      'desc': desc,
      'image_path': userImg,
      'tags': tags
    }).catchError((error) =>
        throw Exception('there´s a problem with the user: Data not stored'));
  }

  Future<MiniUser> getMiniUser(String uid) async{
    MiniUser miniUser;
    await store.collection('users').doc(uid).get().then((value) {
      var data = value.data();
      miniUser = MiniUser(uid, data['name'], data['nickname'], data['image_path']);
    });

    return miniUser;

  }

  Future<User> getUser(String uid) async {
    List<MiniAuthor> favAuthors = await getFavAuthors(uid);
    List<MiniBook> favBooks =
        await getMiniBookCollection(uid, Firestore.favoriteBooks);
    List<MiniBook> history =
        await getHistoryCollection(uid, Firestore.openHistory);
    List<MiniUser> following = await getFollow(uid, Firestore.following);
    List<MiniUser> followers = await getFollow(uid, Firestore.followers);

    Map<String, String> statistics = {
      'books': FormatString.formatStatistic(favBooks.length),
      'followers': FormatString.formatStatistic(followers.length),
      'following': FormatString.formatStatistic(following.length)
    };

    User user;
    await store.collection('users').doc(uid).get().then((value) {
      var data = value.data();
      user = User(
          uid,
          data['name'],
          data['nickname'],
          data['desc'],
          data['theme'],
          data['image_path'],
          followers,
          following,
          data['tags'],
          favAuthors,
          favBooks,
          history,
          statistics);
    });

    return user;
  }

  Future<dynamic> getData(String uid, String data) async {
    String nickName;
    await store.collection('users').doc(uid).get().then((value) {
      nickName = value.data()[data];
    }).catchError((error) => throw Exception('No, we do not have $data data'));

    return nickName;
  }

  Future<List<MiniAuthor>> getFavAuthors(String uid) async {
    List<MiniAuthor> fav = [];
    await store
        .collection('users')
        .doc(uid)
        .collection('favorite_authors')
        .get()
        .then((value) {
      value.docs.forEach((element) {
        var data = element.data();
        fav.add(MiniAuthor(element.id, data['image_url'], data['books_count'],data['followers']));
      });
    });

    return fav;
  }

  /*Future<List<MiniBook>> getHistoryCollection(
      String uid, String collectionName) async {
    List<Map<String, dynamic>> dataList = [];

    await store
        .collection('users')
        .doc(uid)
        .collection(collectionName)
        .get()
        .then((value) {
      value.docs.forEach((element) {
        var data = element.data();
        dataList.add({
          'isbn': element.id,
          'title': data['title'],
          'authors': data['authors'],
          'image_url': data['image_url'],
          'date': data['date']
        });
      });
    });

    List<MiniBook> list = Sort.sortMiniBookByTimeStamp(dataList);

    return list;
  }*/

  Future<List<MiniBook>> getHistoryCollection(
      String uid, String collectionName) async {
    int count = 0;
    MaxHeap heap = MaxHeap();

    await store
        .collection('users')
        .doc(uid)
        .collection(collectionName)
        .get()
        .then((value) {
      value.docs.forEach((element) {
        count++;
        var data = element.data();
        heap.add(TimeMiniBook(
          element.id,
          data['title'],
          data['authors'],
          data['image_url'],
          data['date']
        ));
      });
    });

    List<MiniBook> list = [];
    for(int i = 0; i<count; i++){
      list.add(heap.extractMax());
    }

    return list;
  }

  Future<List<MiniBook>> getMiniBookCollection(
      String uid, String collectionName) async {
    List<MiniBook> list = [];
    await store
        .collection('users')
        .doc(uid)
        .collection(collectionName)
        .get()
        .then((value) {
      value.docs.forEach((element) {
        var data = element.data();
        list.add(MiniBook(
            element.id, data['title'], data['authors'], data['image_url']));
      });
    });

    return list;
  }

  Future<List<MiniUser>> getFollow(String uid, String collectionName) async {
    List<MiniUser> users = [];

    await store
        .collection('users')
        .doc(uid)
        .collection(collectionName)
        .get()
        .then((value) {
      value.docs.forEach((element) {
        var data = element.data();
        users.add(MiniUser(
            element.id, data['name'], data['nickname'], data['image_path']));
      });
    });

    return users;
  }

  Future<bool> isNew(String uid) async {
    String item;
    await store.collection('users').doc(uid).get().then((doc) {
      item = doc.data()['theme'];
    });

    if (item == null) return true;

    return false;
  }

  Future<bool> checkName(String name) async {
    List<String> names = [];
    await store.collection('users').get().then((value) {
      value.docs.forEach((element) {
        names.add(element.data()[nickname]);
      });
    });

    for (int i = 0; i < names.length; i++) {
      if (names[i] == name) return false;
    }
    return true;
  }

  Future<Map<String, dynamic>> loadUserCache(String uid) async {
    Map<String, dynamic> map = {};

    await store.collection('users').doc(uid).get().then((value) {
      map = value.data()['cache'];
    });

    if (map == null) map = {};

    return map;
  }

  Future<ArrayQueue<MiniBook>> getRecommendsQueue(int number) async {
    ArrayQueue<MiniBook> arrayQueue = new ArrayQueue<MiniBook>();
    await store.collection('books').limit(number).get().then((value) {
      value.docs.forEach((element) {
        var data = element.data();
        MiniBook bookito = new MiniBook(data['identifier']['isbn_10'],
            data['title'], data['authors'], data['image_url']);
        arrayQueue.enqueue(bookito);
      });
    });
    return arrayQueue;
  }

  Future<void> getUsersBKTree() async {
    await store.collection('users').get().then((value) {
      value.docs.forEach((element) {
        Search.userBKTree.add(new BKTreeNode(element.data()[nickname], element.id));
      });
    });
  }

  // Books methods ----------------------------------------------------------------------------------------

  Future<MiniBook> getMiniBook(String isbn_10) async{

    String isbn, title, imageUrl;
    double rate;
    List<dynamic> authors;

    await store.collection('books').doc(isbn_10).get().then((value) {
      var data = value.data();
      isbn = value.id;
      title = data['title'];
      imageUrl = data['image_url'];
      rate = data['rate']['stars'];
      authors = data['authors'];
    });

    MiniBook miniBook = MiniBook.search(isbn, title, authors, imageUrl, rate);
    return miniBook;

  }

  Future<Book> getBook(String isbn_10, {userInitialize: true}) async {
    String title, lan, year, publisher, desc, img;
    int views, pages;
    double rate;
    List<dynamic> authors, tags;
    List<dynamic> pdf;
    Map<String, dynamic> buy, isbn;

    await store.collection('books').doc(isbn_10).get().then((value) {
      var data = value.data();
      title = data['title'];
      lan = data['language'];
      year = data['year'].toString();
      publisher = data['publisher'];
      desc = data['desc'];
      img = data['image_url'];
      views = data['views'] == null ? 0 : data['views'];
      pages = data['pages'] == 'null' ? 0 : data['pages'];
      rate = data['rate']['stars'];
      authors = data['authors'];
      tags = data['categories'] == 'null' ? [] : data['categories'];
      pdf = data['pdf_toread'];
      buy = data['buy'];
      isbn = data['identifier'];
    });

    List<MiniAuthor> authorList = [];
    for (dynamic author in authors) {
      Author _author = await this.getAuthor(author);
      MiniAuthor mini = _author.toMiniAuthor();
      authorList.add(mini);
    }

    /*List<BookComment> comments = []; //TODO: sort comments by date

    await store
        .collection('books')
        .doc(isbn_10)
        .collection('comments')
        .get()
        .then((value) {
      value.docs.forEach((element) {
        var data = element.data();
        comments.add(BookComment(data['user_uid'], data['user_name'], data['user_nickname'],
            data['user_image'], data['comment'], data['date']));

      });
    });*/

    Book book = Book(title, lan, year, publisher, desc, img, views, pages, rate,
        authorList, tags, pdf, buy, isbn,
        userInitialize: userInitialize);

    return book;
  }

  Stream<QuerySnapshot> getBookCommentBuilder(String isbn){

    return store.collection('books').doc(isbn).collection('comments').snapshots();

  }
  // author method

  Future<Author> getAuthor(String name) async{

    Author author;
    String bio, birthDate,imageUrl;
    int bookCount,followers;
    List<dynamic> booksNames = [];
    List<MiniBook> miniBooksList = [];

    await store.collection('authors').doc(name).get().then((value) {
      var data = value.data();
      bio = data['bio'];
      birthDate = data['birth_date'];
      booksNames = data['books'];
      bookCount = data['books_count'];
      followers = data['followers'];
      imageUrl = data['image_url'];
    });

    for(var map in booksNames){
      miniBooksList.add(new MiniBook(map["isbn_10"], map["title"], null, map["image_url"]));
    }

    author = Author(name,imageUrl,bio,birthDate,followers,bookCount,miniBooksList);


    return author;

  }

  //SETTERS///////////////////////////////////////////////////////////////////////////////////////

  //user methods-------------------------------------------------------------------

  Future<void> addToMiniBookCollection(
      String uid, String collectionName, MiniBook mini) async {
    await store
        .collection('users')
        .doc(uid)
        .collection(collectionName)
        .doc(mini.isbn10)
        .set({
      'authors': mini.authors,
      'image_url': mini.imageURL,
      'title': mini.title,
      'date': Timestamp.now()
    });
  }

  Future<void> removeFromMiniBookCollection(
      String uid, String collectionName, String isbn) async {
    await store
        .collection('users')
        .doc(uid)
        .collection(collectionName)
        .doc(isbn)
        .delete();
  }

  Future<void> addFollow(String uid, String collectionName, MiniUser mini) async{

    await store.collection('users')
        .doc(uid)
        .collection(collectionName)
        .doc(mini.uid)
        .set({
      'name' : mini.name,
      'nickname' : mini.nickname,
      'image_path' : mini.imagePath
        });
  }

  Future<void> removeFollow(String uid, String collectionName, MiniUser mini) async{

    await store
        .collection('users')
        .doc(uid)
        .collection(collectionName)
        .doc(mini.uid)
        .delete();


  }

  Future<void> addToMiniAuthorCollection(String uid, String collectionName, MiniAuthor mini) async{

    await store
        .collection('users')
        .doc(uid)
        .collection(collectionName)
        .doc(mini.name)
        .set({
      'books_count': mini.booksCount,
      'followers' : mini.followers,
      'image_url' : mini.imageURL
    });

  }

  Future<void> removeFromMiniAuthorCollection(String uid, String collectionName, String name) async{

    await store
        .collection('users')
        .doc(uid)
        .collection(collectionName)
        .doc(name)
        .delete();

  }

  Future<void> addMainUserTag(String uid, String tag) async{

    List<dynamic> tags;

    await store
        .collection('users')
        .doc(uid)
        .get()
        .then((value) {

          tags = value.data()['tags'];

    });

    tags.add(tag);

    await store
        .collection('users')
        .doc(uid)
        .update({
      'tags' : tags

    });
  }

  Future<void> removeMainUserTag(String uid, String tag) async{

    List<dynamic> tags;

    await store.collection('users').doc(uid).get()
      .then((value) {
        tags = value.data()['tags'];

    });

    tags.remove(tag);

    await store
        .collection('users')
        .doc(uid)
        .update({
      'tags' : tags
        });

  }

  Future<void> updateUserInfo(String uid, Map<String, dynamic> cache) async {
    await store.collection('users').doc(uid).update(cache);
  }

  Future<void> setUserTheme(String uid, String option) async {
    if (option != CurrentTheme.orangeTheme && option != CurrentTheme.darkTheme && option != CurrentTheme.blueLight &&option != CurrentTheme.blueDark)
      throw Exception('Invalid theme');

    await store.collection('users').doc(uid).update({'theme': option});
  }

  Future<void> saveUserCache(String uid, Map<String, dynamic> map) async {
    await store.collection('users').doc(uid).update({'cache': map});
  }

  //book method----------------------------------------------------------------------------------------------

  Future<void> rateBook(
      String isbn, double stars, double currentUserRate) async {
    int numUser;
    double sumStars;

    var bookRef = store.collection('books').doc(isbn);

    await bookRef.get().then((value) {
      var data = value.data()['rate'];
      numUser = data['num_users'];
      sumStars = data['sum_stars'];
    });

    numUser += 1;
    sumStars = sumStars + stars - currentUserRate;
    stars = sumStars / numUser;

    String starsText = stars.toStringAsFixed(2);
    stars = double.parse(starsText);

    await bookRef.update({
      'rate': {'num_users': numUser, 'stars': stars, 'sum_stars': sumStars}
    });
  }

  Future<void> updateBookViews(String isbn) async {
    int views;

    var bookRef = store.collection('books').doc(isbn);

    await bookRef.get().then((value) {
      var data = value.data();
      views = data['views'];
    });

    if (views == null)
      views = 1;
    else
      views += 1;

    await bookRef.update({'views': views});
  }

  Future<void> addReadLink(String isbn, String link) async{

    var bookRef = store.collection('books').doc(isbn);

    List<dynamic> links;

    await bookRef.get().then((value) {
      links = value.data()['links'];
    });

    if(links == null) links = List<Map<String,String>>();

    links.add({'isbn':isbn,'link':link,'likes':0});

    await bookRef.update({'links':links});

  }

  Future<void> addComment(String isbn, BookComment bc) async {
    await store.collection('books').doc(isbn).collection('comments').add({
      'user_uid': bc.userUID,
      'user_name': bc.userName,
      'user_nickname': bc.userNickName,
      'user_image': bc.userProfilePic,
      'comment': bc.comment,
      'date': bc.date
    });
  }

  //publication method

  Future<void> createPublication(Publication publication) async{

    await store.collection('publication').add({
      'body' : publication.text,
      'book_image_url': publication.book.imageURL,
      'book_isbn' : publication.book.isbn10,
      'book_title' : publication.book.title,
      'date' : publication.date,
      'user_image_path' : publication.user.imagePath,
      'user_name': publication.user.name,
      'user_nickname' : publication.user.nickname,
      'user_uid' : publication.user.uid
    });

  }

  Future<void> createPublicationWithoutBook(Publication publication) async{

    await store.collection('publication').add({
      'body' : publication.text,
      'date' : publication.date,
      'user_image_path' : publication.user.imagePath,
      'user_name': publication.user.name,
      'user_nickname' : publication.user.nickname,
      'user_uid' : publication.user.uid
    });

  }

  Stream<QuerySnapshot> getForumStream(){

    return store.collection('publication').snapshots();

  }



}
