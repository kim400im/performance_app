import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gpt/gpt_service.dart';
import 'package:flutter_gpt/model/performance_data.dart';
import 'package:flutter_gpt/secrets.dart';
import 'package:http/http.dart' as http; // 이걸 추가하자
import 'package:rxdart/rxdart.dart';

import 'model/open_ai_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  //with로 추가하자
  TextEditingController messageTextController = TextEditingController();
  final List<Messages> _historyList = List.empty(growable: true);

  // 아까 생성한 messages를 넣는다. 리스트로 만든다.

  final PerformanceData _performancesData = PerformanceData();
  final GptService _gptService = GptService();

  //api Key를 입력해 두자
  String apiKey = Secrets.openaiApiKey;
  String streamText = "";

  static const String _kStrings = "공연 추천 GPT";

  String get _currentString => _kStrings;

  ScrollController scrollController = ScrollController(); //scrollcontroller 설정
  late Animation<int> _characterCount; // animation 을 넣기 위해 설정
  late AnimationController animationController;

  void _scrollDown() {
    // scrollDown은 request챗에서 사용할것
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: 350),
      curve: Curves.fastOutSlowIn,
    );
  }

  setUpAnimations() {
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _characterCount = StepTween(begin: 0, end: _currentString.length).animate(
      // stepTween은 시작과 끝이 있다.
      CurvedAnimation(parent: animationController, curve: Curves.easeIn),
    ); // 여기까지 해야 animation과 animationcontroller가 설정된다.
    animationController.addListener(() {
      // setState(() {});
      if (_characterCount.value <= _currentString.length) {
        setState(() {});
      }
    }); // setState를 넣어야 애니매이션이 시작될때마다 화면이 빌드가 된다.
    animationController.addStatusListener((status) {
      //addStatusListener는 애니메이션이 돌아가고 있느냐를 판단한다.
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 1)).then((value) {
          animationController.reverse(); // animation이 완료가 되면 1초 쉬고 뒤로 보낸다.
        });
      } else if (status == AnimationStatus.dismissed) {
        Future.delayed(const Duration(seconds: 1)).then(
              (value) => animationController.forward(),
        );
      }
    });

    animationController.forward(); // 이게 있어야 실행이 됨
  }

  Future requestChat(String text) async {
    ChatCompletionModel openAiModel = ChatCompletionModel(
        model: "gpt-4o",
        messages: [
          Messages(
            role: "system",
            content: "You are a helpful assistant.",
          ),
          ..._historyList,
        ],
        stream: false);
    //history를 누적해줘야 한다.
    final url = Uri.https("api.openai.com", "/v1/chat/completions");
    final resp = await http.post(url,
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode(openAiModel.toJson()));
    print(resp.body);
    if (resp.statusCode == 200) {
      // 성공일 때 json 바디를 passing 해서 오브젝트로 만들어보자
      final jsonData = jsonDecode(utf8.decode(resp.bodyBytes)) as Map;
      // 한글은 utf8을 해주자
      String role = jsonData["choices"][0]["message"]["role"];
      String content = jsonData["choices"][0]["message"]["content"];
      _historyList.last = _historyList.last.copyWith(
        role: role,
        content: content,
      );
      setState(() {
        _scrollDown();
      });
    }
    // 비동기니까 await 사용
  }

  //stream을 구현해보자.
  Stream requestChatStream(String text) async* {


    // 사용자 입력을 벡터화하여 관련 데이터를 검색
    List<Map<String, String>> searchResults;
    try {
      searchResults = await _performancesData.search(text);
    } catch (e) {
      yield "Error during vector search: $e";
      setState(() {
        _historyList.last = _historyList.last.copyWith(content: "Error: $e");
      });
      return;
    }


    // 검색 결과를 기반으로 GPT 프롬프트 생성
    StringBuffer prompt = StringBuffer();
    if (searchResults.isEmpty) {
      prompt.writeln("User asked: \"$text\"\nNo relevant performance found.");
    } else {
      prompt.writeln("You are a helpful assistant. Here is the performance information:");
      for (var performance in searchResults) {
        prompt.writeln(
            "- Start Date: ${performance['performance_start_date']}, "
                "End Date: ${performance['performance_end_date']}, "
                "Serial Number: ${performance['performance_serial_number']}, "
                "Genre: ${performance['performance_genre']}, "
                "Name: ${performance['performance_name']}, "
                "Place: ${performance['performance_place']}, "
                "Running Time: ${performance['performance_runningtime']}, "
                "Intermission: ${performance['performance_intermission']}, "
                "Age Restriction: ${performance['performance_age']}, "
                "Synopsis: ${performance['performance_synopsis']}, "
                "Work Description: ${performance['performance_work_description']}, "
                "Discount Info: ${performance['performance_discount_info']}, "
                "Seat Info: ${performance['performance_seat_info']}");
      }
      prompt.writeln("\nBased on the information, answer the following question:");
      prompt.writeln(text);
    }

    ChatCompletionModel openAiModel = ChatCompletionModel(
      model: "gpt-4o",
      messages: [
        Messages(
          role: "system",
          content: "You are a helpful assistant.",
        ),
        Messages(role: "user", content: prompt.toString()),
        ..._historyList,
      ],
      stream: true,
    );

    final url = Uri.https("api.openai.com", "/v1/chat/completions");
    final request = http.Request("POST", url)
      ..headers.addAll(
        {
          "Authorization": "Bearer $apiKey", // 인증
          "Content-Type": 'application/json; charset=UTF-8', // json 넣기
          "Connection": "keep-alive",
          "Accept": "*/*",
          "Accept-Encoding": "gzip, deflate, br",
        },
      ); // 이렇게 헤더를 준비
    request.body = jsonEncode(openAiModel.toJson());

    final resp = await http.Client().send(request);
    final byteStream = resp.stream.asyncExpand(
          (event) => Rx.timer(
        //Rx.timer는 이벤트를 받고 지연시켜준다.
        event,
        Duration(milliseconds: 50),
      ),
    );
    final statusCode = resp.statusCode;
    var respText = "";

    /*await for (final byte in byteStream) {
      // 스트림 안에 값이 끝날때까지 반복
      var decode = utf8.decode(byte, allowMalformed: false);
      final strings = decode.split("data: "); // 이걸 기준으로 데이터를 자른다.
      for (final string in strings) {
        final trimmedString = string.trim(); // 공백 제어
        if (trimmedString.isNotEmpty && !trimmedString.endsWith("[DONE]")) {
          // 만약 자른 문장이 비어있지 않거나 DONE이라는 직결자로 끝나지 않는다면
          // 데이터 처리를 해준다.
          // 스트림이 끝날때 DONE이 들어간다.
          final map = jsonDecode(trimmedString) as Map;
          final choices = map["choices"] as List;
          final delta = choices[0]["delta"] as Map;
          if (delta["content"] != null) {
            final content = delta["content"] as String;
            respText += content; // content 값을 계속 누적한다.
            setState(() {
              streamText = respText;
            });
            yield content; // content를 byteStream 끝날때까지 돌게 한다.
          }
        }
      }*/
    await for (final byte in byteStream) {
      try {
        var decoded = utf8.decode(byte, allowMalformed: false);
        if (decoded.contains('"content":')) {
          final strings = decoded.split("data: ");
          for (final string in strings) {
            final trimmedString = string.trim();
            if (trimmedString.isNotEmpty && !trimmedString.endsWith("[DONE]")) {
              final map = jsonDecode(trimmedString) as Map;
              final choices = map["choices"] as List;
              final delta = choices[0]["delta"] as Map;
              if (delta["content"] != null) {
                final content = delta["content"] as String;
                respText += content;
                setState(() {
                  streamText = respText;
                });
                yield content;
              }
            }
          }
        }
      } catch (e) {
        print(e.toString());
      }
    }

    if (respText.isNotEmpty) {
      setState(() {});
    }
  }



  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _performancesData.loadCSV().then((_) {
      print("Performance data loaded successfully.");
    }).catchError((e) {
      print("Failed to load performance data: $e");
    });
    setUpAnimations();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    messageTextController.dispose();
    scrollController.dispose(); // dispose 꼭 해줘야 함.

    super.dispose();
  }

  //옆으로 넘기면 초기화하는 기능을 구현하자
  Future clearChat() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("새로운 대화의 시작"),
        content: Text("신규 대화를 시작하겠어요?"),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigator.of(context).pop();는 현재 열린 다일로그가 닫히게 해준다.
                setState(() {
                  messageTextController.clear();
                  _historyList.clear();
                });
              },
              child: Text("네"))
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        //상태바 아래에서 시작하도록 경계 만들기
        child: Padding(
          padding: const EdgeInsets.all(16.0), // 패딩을 주자
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Align(
                // 오른쪽에 뜨도록 align으로 묶는다.
                alignment: Alignment.centerRight,
                child: Card(
                  child: PopupMenuButton(
                    // 눌렀을 때 메뉴가 뜬다.
                    itemBuilder: (context) {
                      return [
                        const PopupMenuItem(
                          child: ListTile(
                            title: Text('히스토리'),
                          ),
                        ),
                        const PopupMenuItem(
                          child: ListTile(
                            title: Text('설정'),
                          ),
                        ),
                        PopupMenuItem(
                          onTap: () {
                            clearChat();
                          },
                          child: ListTile(
                            title: Text('새로운 채팅'),
                          ),
                        ),
                      ];
                    },
                  ),
                ),
              ),
              Expanded(
                // Container 대신 animatedbuilder를 넣자
                child: _historyList.isEmpty
                    ? Center(
                  // 비어있다면의 상황
                  child: AnimatedBuilder(
                    animation: _characterCount,
                    builder: (BuildContext context, Widget? child) {
                      final safeEnd = _characterCount.value.clamp(0, _currentString.length);
                      // print("Safe End Value: $safeEnd, String Length: ${_currentString.length}");
                      String text = _currentString.substring(
                          0, _characterCount.value.clamp(0, safeEnd));
                      return Row(
                        children: [
                          Text(
                            "${text}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                          CircleAvatar(
                            radius: 8,
                            backgroundColor: Colors.blue[200],
                          )
                        ],
                      );
                    },
                    //color: Colors.blue,
                    //child: Center(
                    // child: Text(_kStrings),
                    //),  파란 배경을 지움
                  ),
                )
                    : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount:
                    _historyList.length, // item을 history 길이로 설정
                    itemBuilder: (context, index) {
                      if (_historyList[index].role == "user") {
                        // 임시로 작성해보자.
                        return Padding(
                          padding:
                          const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundImage: AssetImage('assets/images/user.png'),
                              ),
                              const SizedBox(
                                width: 8, // 원이랑 글자 사이의 거리
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  //왼쪽으로 정렬
                                  children: [
                                    const Text("나"),
                                    Text(_historyList[index].content),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            // backgroundColor: Colors.teal,
                            backgroundImage: AssetImage('assets/images/dodge.jpg'),
                          ),
                          SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text("공연 GPT"),
                                Text(_historyList[index].content),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Dismissible(
                // 텍스트 바를 오른쪽으로 움직일 수 있다.
                key: const Key("chat-bar"),
                direction: DismissDirection.startToEnd,
                onDismissed: (d) {
                  if (d == DismissDirection.startToEnd) {}
                },
                background: const Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text("New Chat"),
                  ],
                ),
                // 밀어서 새 채팅은 confirmDismiss에 넣어줘야한다.
                confirmDismiss: (d) async {
                  if (d == DismissDirection.startToEnd) {
                    // logic
                    if (_historyList.isEmpty) return;
                    clearChat();
                  }
                },
                child: Row(
                  children: [
                    Expanded(
                      // 사이즈를 정해줘야 해서 expanded 사용
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(),
                        ),
                        child: TextField(
                          controller: messageTextController,
                          decoration: const InputDecoration(
                            border: InputBorder.none, //밑줄 삭제함
                            hintText: "Message",
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      iconSize: 42,
                      onPressed: () async {
                        if (messageTextController.text.isEmpty) {
                          // await _handleUserQuery(messageTextController.text.trim());
                          return;
                          // 메시지가 없을 때 return
                          // 토큰을 아껴야 한다.
                        }
                        setState(() {
                          _historyList.add(
                            Messages(
                                role: "user",
                                content: messageTextController.text.trim()),
                          );
                          _historyList
                              .add(Messages(role: "assistant", content: ""));
                        });
                        try {
                          var text = "";
                          final stream = requestChatStream(
                              messageTextController.text.trim());
                          await for (final textChunk in stream) {
                            text += textChunk;
                            setState(() {
                              _historyList.last = // history의 마지막 값을 계속 갱신한다.
                              _historyList.last.copyWith(content: text);
                              _scrollDown(); // 값이 길어지면 스크롤을 내려준다.
                            });
                          }
                          //await requestChat(messageTextController.text.trim());
                          messageTextController.clear();
                          streamText = "";
                          //requestChat(messageTextController.text.trim());
                        } catch (e) {
                          print(e.toString());
                        }
                      },
                      icon: const Icon(Icons.arrow_circle_up),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

