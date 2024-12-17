// Message
class Messages {
  // message 는 role 과 content를 받는다.
  late final String role;
  late final String content;

  Messages(
      { // 생성자를 만들자. 2개는 모두 null 값이 될 수 없으므로 required를 넣었다.
      required this.role,
      required this.content});

  Messages.fromJson(Map<String, dynamic> json) {
    role = json['role'];
    content = json['content']; // api를 호출할 때 내부에 role과 content가 존재한다. 그 값을 가져온다.
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data["role"] = role;
    data["content"] = content;
    return data;
  }

  Map<String, String> toMap() {
    return {"role": role, "content": content};
  }

  Messages copyWith({String? role, String? content}) {
    return Messages(
      role: role ?? this.role,
      content: content ?? this.content,
    );
    // 만약 role 이나 content가 널이면 this를 붙인다.
  }
}
// ChatCompletionModel
// gpt를 호출할 때 사용할 모델을 만들어보자

// chatcompletion은 model, message, stream을 받는다.
class ChatCompletionModel {
  late final String model;
  late final List<Messages> messages;
  late final bool stream;

  ChatCompletionModel({
    required this.model,
    required this.messages,
    required this.stream,
  });

  ChatCompletionModel.fromJson(Map<String, dynamic> json){
    model = json['model'];
    messages = List.from(json["messages"]).map((e) => Messages.fromJson(e)).toList();
    // 값을 받어서 list로 만든다.

    stream = json[stream];
  }

  Map<String, dynamic> toJson(){
    final data =<String, dynamic>{};
    data['model'] = model;
    data['messages'] = messages.map((e) => e.toJson()).toList();
    data['stream'] = stream;
    return data;
  }
}
