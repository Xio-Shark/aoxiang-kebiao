# 璇剧▼琛ㄥ簲鐢?- aoxiang Schedule

鍩轰簬 Flutter Clean Architecture + Go 瑙ｆ瀽鏈嶅姟鐨勮绋嬭〃搴旂敤銆?
## 椤圭洰缁撴瀯

```
schedule-app/
鈹溾攢鈹€ mobile_app/          # Flutter 绉诲姩绔?鈹?  鈹溾攢鈹€ lib/
鈹?  鈹?  鈹溾攢鈹€ core/        # 鏍稿績妯″潡锛堥敊璇鐞嗐€佺粨鏋滅被鍨嬨€佸父閲忥級
鈹?  鈹?  鈹溾攢鈹€ domain/      # 棰嗗煙灞傦紙瀹炰綋銆丷epository鎺ュ彛锛?鈹?  鈹?  鈹溾攢鈹€ data/        # 鏁版嵁灞傦紙Models銆佹湰鍦板瓨鍌級
鈹?  鈹?  鈹溾攢鈹€ application/ # 搴旂敤灞傦紙UseCases銆丳roviders锛?鈹?  鈹?  鈹斺攢鈹€ presentation/# 琛ㄧ幇灞傦紙椤甸潰銆佺粍浠躲€乂iewModels锛?鈹?  鈹溾攢鈹€ test/            # 鍗曞厓娴嬭瘯
鈹?  鈹斺攢鈹€ integration_test/# 闆嗘垚娴嬭瘯
鈹?鈹斺攢鈹€ parsing_service/     # Go 瑙ｆ瀽寰湇鍔?    鈹溾攢鈹€ internal/        # 鍐呴儴瀹炵幇
    鈹?  鈹溾攢鈹€ parser/      # DOCX瑙ｆ瀽
    鈹?  鈹溾攢鈹€ recognizer/  # 鏂囨湰璇嗗埆
    鈹?  鈹溾攢鈹€ api/         # HTTP API
    鈹?  鈹斺攢鈹€ model/       # 鏁版嵁妯″瀷
    鈹溾攢鈹€ pkg/             # 鍏叡鍖?    鈹斺攢鈹€ cmd/             # 鍏ュ彛鐐?```

## 鎶€鏈爤

### 绉诲姩绔?(Flutter)
- **鐘舵€佺鐞?*: Riverpod 2.x
- **鏋舵瀯妯″紡**: Clean Architecture
- **涓嶅彲鍙樻暟鎹?*: Freezed
- **鏈湴瀛樺偍**: SharedPreferences
- **缃戠粶璇锋眰**: Dio / HTTP

### 鍚庣 (Go)
- **DOCX瑙ｆ瀽**: unioffice/v2
- **HTTP妗嗘灦**: Gin
- **鏃ュ織**: Logrus
- **閰嶇疆**: YAML

## 蹇€熷紑濮?
### Flutter 绉诲姩绔?
```bash
cd mobile_app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

### Go 瑙ｆ瀽鏈嶅姟

```bash
cd parsing_service
go mod tidy
go run cmd/server/main.go
```

## 鍔熻兘鐗规€?
- 鉁?璇剧▼琛ㄥ睍绀猴紙鎸夊懆娆°€佹槦鏈熴€佽妭娆★級
- 鉁?鍗曞弻鍛ㄨ绋嬫樉绀?- 鉁?浠嶹ord鏂囨。瀵煎叆璇剧▼琛?- 鉁?鍛ㄦ鑷姩璁＄畻
- 鉁?璇剧▼璇︽儏鏌ョ湅涓庣紪杈?- 鉁?瀛︽湡璁剧疆

## 浠ｇ爜瑙勮寖

- 閬靛惊 Clean Architecture 鍒嗗眰鍘熷垯
- Presentation灞備笉鐩存帴璁块棶Data灞?- Repository閫氳繃鎺ュ彛璋冪敤
- Domain灞備笉渚濊禆Flutter妗嗘灦

## 璁稿彲璇?
MIT


