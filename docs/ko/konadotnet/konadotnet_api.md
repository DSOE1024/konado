---
title: API 사용
order: 2
---

# Konado .NET API

> 이 기능은 아직 실험적 기능이며 일부 문제가 있을 수 있습니다.

## 소개

Konado.NET은 Konado 대화 시스템의 C# API 확장입니다. Konado.NET을 사용하면 개발자가 C# 프로젝트에서 대화 내용을 쉽게 생성, 관리, 실행할 수 있습니다.

## 사용 방법

### 비 .NET 프로젝트

비 .NET 프로젝트에서 Konado .NET API를 사용하면 다음 오류가 발생할 수 있으며, 이는 정상적인 현상입니다.
```
 ERROR: core/io/resource_loader.cpp:568 - Condition "local_path.is_empty()" is true. Returning: Ref<ResourceLoader::LoadToken>()
  ERROR: Failed to create an autoload, can't load from UID or path: uid://ptylvcqylq7j.
  ERROR: editor/settings/editor_autoload_settings.cpp:571 - Condition "!info->node" is true. Continuing.

```

이 문제는 Konado 기본 기능 사용에는 영향을 주지 않지만, Konado .NET API는 사용할 수 없습니다.

### 플러그인 활성화

먼저 Konado 플러그인을 활성화한 뒤 Konado .NET API 플러그인을 활성화하세요.

장면에는 DialogueManager 노드가 포함되어야 합니다. 그렇지 않으면 Konado .NET API가 정상적으로 동작하지 않습니다.

Konado.NET을 처음 활성화할 때 다음 오류가 발생할 수 있습니다.

```
“res://addons/konadotnet/Konadotnet.cs” 경로에서 애드온 스크립트를 로드할 수 없습니다. 스크립트에 코드 오류가 있을 수 있습니다.
추가 오류를 막기 위해 “res://addons/konadotnet/plugin.cfg” 위치의 애드온을 비활성화합니다.
```

```
Unable to load addon script from path: 'res://addons/konadotnet/Konadotnet.cs'.
```

이는 정상적인 현상입니다. Godot에서 Konado.NET을 다시 빌드한 다음 프로젝트를 다시 열면 해결됩니다.

플러그인을 활성화할 수 없고 MSBuild에 아무 오류도 없다면, 프로젝트를 닫은 뒤 프로젝트 루트 디렉터리의 `.godot/` 폴더를 삭제하고 프로젝트를 다시 생성해 보세요.

## API 참조

### KonadoAPI

Konado 시스템에 접근하기 위한 핵심 API 클래스입니다.

#### 속성

- `bool IsApiReady`: API가 준비되었는지 나타냅니다
- `KonadoAPI API`: Konado API 접근을 제공하는 정적 인스턴스
- `DialogueManagerAPI DialogueManagerApi`: 대화 관리자 API 인스턴스

### DialogueManagerAPI

대화 실행을 제어하는 대화 관리자 API입니다.

#### 메서드

- `InitDialogue()`: 대화 초기화
- `StartDialogue()`: 대화 시작
- `StopDialogue()`: 대화 정지

#### 이벤트

- `ShotStart`: 대화 장면이 시작될 때 트리거됩니다
- `ShotEnd`: 대화 장면이 끝날 때 트리거됩니다
- `DialogueLineStart(int line)`: 대화 줄이 시작될 때 트리거됩니다
- `DialogueLineEnd(int line)`: 대화 줄이 끝날 때 트리거됩니다

### ActingInterface

배경 전환 효과 유형을 정의하는 연출 인터페이스입니다.

#### 열거형

- `BackgroundTransitionEffectsType`: 배경 전환 효과 유형
  - `NoneEffect`: 효과 없음
  - `EraseEffect`: 지우기 효과
  - `BlindsEffect`: 블라인드 효과
  - `WaveEffect`: 파동 효과
  - `AlphaFadeEffect`: 투명도 페이드 효과
  - `VortexSwapEffect`: 소용돌이 전환 효과
  - `WindmillEffect`: 풍차 효과
  - `CyberGlitchEffect`: 사이버 글리치 효과

### Wrapper 클래스

Wrapper 클래스는 GDScript 객체에 대한 C# 래퍼를 제공하여 개발자가 C#에서 Konado의 다양한 데이터 구조를 조작할 수 있게 합니다. 다만 현재 이 클래스들은 완전히 구현되어 있지 않으며 일부 속성과 메서드만 제공합니다. 앞으로 더 개선될 예정입니다.

#### Dialogue

단일 대화 요소를 나타내는 대화 객체 래퍼입니다.

##### 속성

- `Type DialogueType`: 대화 유형(열거형)
- `string BranchId`: 분기 ID
- `Array<Dialogue> BranchDialogue`: 분기 대화
- `bool IsBranchLoaded`: 분기 로드 여부
- `string CharacterId`: 캐릭터 ID
- `string DialogueContent`: 대화 내용
- `DialogueActor ShowActor`: 표시할 캐릭터
- `string ExitActor`: 퇴장할 캐릭터
- `string ChangeStateActor`: 상태가 변경되는 캐릭터
- `string TargetMoveChara`: 이동 대상 캐릭터
- `Vector2 TargetMovePos`: 이동 목표 위치
- `Array<DialogueChoice> Choices`: 대화 선택지
- `string BgmName`: 배경 음악 이름
- `string VoiceId`: 음성 ID
- `string SoundeffectName`: 효과음 이름
- `string BackgroundImageName`: 배경 이미지 이름
- `BackgroundTransitionEffectsType BackgroundToggleEffects`: 배경 전환 효과
- `string JumpShotId`: 이동할 장면 ID
- `string LabelNotes`: 라벨 주석
- `Dictionary ActorSnapshots`: 캐릭터 스냅샷

##### 대화 유형 열거형

- `Start`: 시작
- `OrdinaryDialog`: 일반 대화
- `DisplayActor`: 캐릭터 표시
- `ActorChangeState`: 캐릭터 상태 변경
- `MoveActor`: 캐릭터 이동
- `SwitchBackground`: 배경 전환
- `ExitActor`: 캐릭터 퇴장
- `PlayBgm`: 배경 음악 재생
- `StopBgm`: 배경 음악 정지
- `PlaySoundEffect`: 효과음 재생
- `ShowChoice`: 선택지 표시
- `Branch`: 분기
- `JumpTag`: 태그로 점프
- `JumpShot`: 장면으로 점프
- `TheEnd`: 종료
- `Label`: 라벨

#### DialogueActor

대화 안의 캐릭터 객체를 나타내는 대화 캐릭터 래퍼입니다.

##### 속성

- `string CharacterName`: 캐릭터 이름
- `string CharacterState`: 캐릭터 상태
- `Vector2 ActorPosition`: 캐릭터 위치
- `Vector2 ActorScale`: 캐릭터 스케일
- `bool ActorMirror`: 캐릭터 미러링

#### DialogueChoice

대화 안의 선택지 객체를 나타내는 대화 선택지 래퍼입니다.

##### 속성

- `string ChoiceText`: 선택지 텍스트
- `string JumpTag`: 점프 태그

#### KndData

Konado KND_Data 데이터 기반 클래스 래퍼입니다.

##### 속성

- `string Type`: 데이터 유형
- `bool Love`: 선호 콘텐츠 여부
- `string Tip`: 안내 정보

#### KndShot

KndData를 상속하는 Konado KND_Shot 샷 래퍼입니다.

##### 속성

- `string Name`: 장면 이름
- `string ShotId`: 장면 ID
- `string SourceStory`: 원본 이야기
- `Array<Dictionary> DialoguesSourceData`: 대화 원본 데이터
- `Dictionary Branches`: 분기
- `Dictionary<string, Dictionary> SourceBranches`: 원본 분기
- `Dictionary<string, int> ActorCharacterMap`: 캐릭터 매핑

#### KonadoScriptsInterpreter

Konado 스크립트 파일을 파싱하는 데 사용되는 KonadoScriptsInterpreter 스크립트 인터프리터 래퍼입니다.

##### 메서드

- `KndShot ProcessScriptsToData(string path)`: 스크립트 파일을 데이터로 처리
- `Dialogue ParseSingleLine(string line, long lineNumber, string path)`: 단일 스크립트 줄 파싱

## 예시 코드

### 대화 관리

```csharp
using Konado.Runtime.API;

// Konado API 인스턴스 가져오기
var konadoAPI = KonadoAPI.API;
var dialogueManager = KonadoAPI.DialogueManagerApi;

// API 준비 여부 확인
if (dialogueManager.IsReady)
{
    // 대화 초기화
    dialogueManager.InitDialogue();

    // 대화 시작
    dialogueManager.StartDialogue();

    // 대화 정지
    dialogueManager.StopDialogue();
}
```

### 대화 이벤트 감시

```csharp
// 대화 시작 이벤트 감시
dialogueManager.ShotStart += () => {
    GD.Print("대화 장면 시작");
};

// 대화 종료 이벤트 감시
dialogueManager.ShotEnd += () => {
    GD.Print("대화 장면 종료");
};

// 대화 줄 시작 이벤트 감시
dialogueManager.DialogueLineStart += (int line) => {
    GD.Print($"대화 줄 {line} 시작");
};

// 대화 줄 종료 이벤트 감시
dialogueManager.DialogueLineEnd += (int line) => {
    GD.Print($"대화 줄 {line} 종료");
};
```

### Konado 스크립트 파싱

```csharp
using Konado.Wrapper;

// 스크립트 인터프리터 생성
var flags = new Godot.Collections.Dictionary<string, Variant>();
var interpreter = new KonadoScriptsInterpreter(flags);

// 전체 스크립트 파일 파싱
var shot = interpreter.ProcessScriptsToData("res://dialogues/example.ks");
```
