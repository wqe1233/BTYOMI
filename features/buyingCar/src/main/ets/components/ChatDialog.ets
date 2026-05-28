import { CommonConstants } from '@ohos/common';
import { AICarRecommendService } from '../service/AICarRecommendService';
import { SpeechRecognitionService } from '../service/SpeechRecognitionService';
import type { ChatMessage, RecommendResult, UserPreferences } from '../model/AICarModel';

@Component
export struct ChatDialog {
  @Link isVisible: boolean;
  @State messages: ChatMessage[] = [];
  @State inputText: string = '';
  @State isLoading: boolean = false;
  @State recommendations: RecommendResult[] = [];
  @State showRecommendations: boolean = false;
  @State isListening: boolean = false;
  @State showVoiceAnimation: boolean = false;

  private recommendService: AICarRecommendService = AICarRecommendService.getInstance();
  private speechService: SpeechRecognitionService = SpeechRecognitionService.getInstance();

  aboutToAppear() {
    this.messages = [
      {
        id: 'welcome',
        role: 'assistant',
        content: '您好！我是您的智能购车助手，请问有什么可以帮助您的？',
        timestamp: Date.now(),
        type: 'text'
      }
    ];
    this.setupSpeechListener();
  }

  private setupSpeechListener(): void {
    this.speechService.setListener({
      onResult: (text: string) => {
        this.inputText = text;
        this.showVoiceAnimation = false;
      },
      onError: (error: string) => {
        console.error('语音识别错误:', error);
        this.isListening = false;
        this.showVoiceAnimation = false;
      },
      onStateChange: (state: 'idle' | 'listening' | 'recognizing' | 'finished') => {
        if (state === 'finished') {
          this.isListening = false;
          this.showVoiceAnimation = false;
        }
      }
    });
  }

  build() {
    Column() {
      if (!this.isVisible) {
        Blank().width('100%').height('100%');
      } else {
        this.buildContent();
      }
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  buildContent() {
    Column({ space: 0 }) {
      this.buildHeader();

      Stack({ alignContent: Alignment.Bottom }) {
        if (this.showRecommendations) {
          this.buildRecommendations();
        } else {
          this.buildChatArea();
        }
      }
      .width('100%')
      .height('0')
      .flexGrow(1);

      Row({ space: 12 }) {
        Button() {
          Image($r('app.media.scan'))
            .width(20)
            .height(20)
            .fillColor(this.isListening ? '#FFFFFF' : '#666666');
        }
        .width(44)
        .height(44)
        .backgroundColor(this.isListening ? '#E74C3C' : '#F5F5F5')
        .borderRadius(22)
        .onClick(() => {
          this.toggleVoiceInput();
        });

        TextInput({ placeholder: '输入您的问题...' })
          .width('flex')
          .flexGrow(1)
          .height(44)
          .backgroundColor('#F5F5F5')
          .borderRadius(22)
          .padding({ left: 16 })
          .fontSize(14)
          .onChange((value: string) => {
            this.inputText = value;
          })
          .onSubmit(() => {
            this.sendMessage();
          });

        Button() {
          Image($r('app.media.search'))
            .width(20)
            .height(20)
            .fillColor('#FFFFFF');
        }
        .width(44)
        .height(44)
        .backgroundColor('#2ECC71')
        .borderRadius(22)
        .onClick(() => {
          this.sendMessage();
        });
      }
      .width('100%')
      .padding({ left: CommonConstants.PUBLIC_SPACE, right: CommonConstants.PUBLIC_SPACE, bottom: 20, top: 12 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF');
  }

  @Builder
  buildHeader() {
    Row({ space: 12 }) {
      Image($r('app.media.AI_search'))
        .width(28)
        .height(28)
        .fillColor('#2ECC71');
      Column({ space: 2 }) {
        Text('智能助手')
          .fontSize(16)
          .fontWeight(700)
          .fontColor('#333333');
        Text('正在为您服务')
          .fontSize(12)
          .fontColor('#2ECC71');
      }
      Blank()
        .flexGrow(1);
      Image($r('app.media.split'))
        .width(24)
        .height(24)
        .fillColor('#999999')
        .onClick(() => {
          this.isVisible = false;
        });
    }
    .width('100%')
    .padding({ top: CommonConstants.PUBLIC_SPACE, left: CommonConstants.PUBLIC_SPACE, right: CommonConstants.PUBLIC_SPACE });
  }

  @Builder
  buildChatArea() {
    Scroll() {
      Column({ space: 16 }) {
        ForEach(this.messages, (message: ChatMessage) => {
          if (message.role === 'user') {
            this.buildUserMessage(message);
          } else {
            this.buildAssistantMessage(message);
          }
        });
      }
      .width('100%')
      .padding({ top: 16, left: CommonConstants.PUBLIC_SPACE, right: CommonConstants.PUBLIC_SPACE, bottom: 80 });
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  buildUserMessage(message: ChatMessage) {
    Row({ space: 12 }) {
      Blank()
        .flexGrow(1);
      Column({ space: 8 }) {
        Text(message.content)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#2ECC71')
          .padding({ top: 10, bottom: 10, left: 16, right: 16 })
          .borderRadius({ topLeft: 16, topRight: 4, bottomLeft: 16, bottomRight: 16 })
          .width('70%');
        Text(this.formatTime(message.timestamp))
          .fontSize(10)
          .fontColor('#999999')
          .textAlign(TextAlign.End);
      }
    }
    .width('100%');
  }

  @Builder
  buildAssistantMessage(message: ChatMessage) {
    Row({ space: 12 }) {
      Image($r('app.media.AI_search'))
        .width(40)
        .height(40)
        .fillColor('#E8F5E9')
        .borderRadius(20);
      Column({ space: 8 }) {
        if (message.type === 'recommendation') {
          this.buildRecommendations();
        } else {
          Text(message.content)
            .fontSize(14)
            .fontColor('#333333')
            .backgroundColor('#F5F5F5')
            .padding({ top: 10, bottom: 10, left: 16, right: 16 })
            .borderRadius({ topLeft: 4, topRight: 16, bottomLeft: 16, bottomRight: 16 })
            .width('70%');
        }
        Text(this.formatTime(message.timestamp))
          .fontSize(10)
          .fontColor('#999999');
      }
    }
    .width('100%');
  }

  @Builder
  buildRecommendations() {
    Column({ space: 20 }) {
      Row({ space: 8 }) {
        Image($r('app.media.AI_search'))
          .width(20)
          .height(20)
          .fillColor('#2ECC71');
        Text('为您推荐以下车型')
          .fontSize(16)
          .fontWeight(700)
          .fontColor('#333333');
      }
      .width('100%')
      .padding({ top: 16, left: CommonConstants.PUBLIC_SPACE });

      List({ space: 16 }) {
        ForEach(this.recommendations, (result: RecommendResult, index: number) => {
          ListItem() {
            Column({ space: 12 }) {
              Row({ space: 16 }) {
                Stack({ alignContent: Alignment.TopStart }) {
                  Image($r('app.media.' + result.car.image))
                    .width(100)
                    .height(80)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(8);
                  Stack({ alignContent: Alignment.Center }) {
                    Text((index + 1).toString())
                      .fontSize(14)
                      .fontWeight(700)
                      .fontColor('#FFFFFF');
                  }
                  .width(24)
                  .height(24)
                  .backgroundColor('#2ECC71')
                  .borderRadius({ topLeft: 8, bottomRight: 8 });
                }
                Column({ space: 8 }) {
                  Text(`${result.car.brand} ${result.car.model}`)
                    .fontSize(16)
                    .fontWeight(700)
                    .fontColor('#333333');
                  Row({ space: 16 }) {
                    Text(result.car.price)
                      .fontSize(14)
                      .fontColor('#E74C3C');
                    Text(result.car.range)
                      .fontSize(14)
                      .fontColor('#3498DB');
                    Text(result.car.powerType)
                      .fontSize(14)
                      .fontColor('#9B59B6');
                  }
                  Stack({ alignContent: Alignment.Center }) {
                    Text(`匹配度 ${result.score}%`)
                      .fontSize(12)
                      .fontWeight(700)
                      .fontColor(result.score >= 80 ? '#2ECC71' : result.score >= 60 ? '#F39C12' : '#E74C3C');
                  }
                  .width(80)
                  .height(28)
                  .backgroundColor('rgba(46, 204, 113, 0.1)')
                  .borderRadius(14);
                }
              }
              Column({ space: 4 }) {
                ForEach(result.reasons.slice(0, 3), (reason: string) => {
                  Row({ space: 8 }) {
                    Image($r('app.media.search'))
                      .width(14)
                      .height(14)
                      .fillColor('#2ECC71');
                    Text(reason)
                      .fontSize(12)
                      .fontColor('#666666');
                  }
                });
              }
              .padding({ left: 16 })
              .backgroundColor('#FAFAFA')
              .borderRadius(8)
              .padding({ top: 8, bottom: 8 });
            }
            .width('100%')
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .padding({ top: 12, bottom: 12, left: 12, right: 12 });
          }
        });
      }
      .width('100%')
      .layoutWeight(1)
      .height('100%')
      .padding({ left: CommonConstants.PUBLIC_SPACE, right: CommonConstants.PUBLIC_SPACE });
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  buildInput() {
    Row({ space: 12 }) {
      Button() {
        Image($r('app.media.scan'))
          .width(20)
          .height(20)
          .fillColor(this.isListening ? '#FFFFFF' : '#666666');
      }
      .width(44)
      .height(44)
      .backgroundColor(this.isListening ? '#E74C3C' : '#F5F5F5')
      .borderRadius(22)
      .onClick(() => {
        this.toggleVoiceInput();
      });

      TextInput({ placeholder: '输入您的问题...' })
        .width('flex')
        .flexGrow(1)
        .height(44)
        .backgroundColor('#F5F5F5')
        .borderRadius(22)
        .padding({ left: 16 })
        .fontSize(14)
        .onChange((value: string) => {
          this.inputText = value;
        })
        .onSubmit(() => {
          this.sendMessage();
        });
      Button() {
        Image($r('app.media.search'))
          .width(20)
          .height(20)
          .fillColor('#FFFFFF');
      }
      .width(44)
      .height(44)
      .backgroundColor('#2ECC71')
      .borderRadius(22)
      .onClick(() => {
        this.sendMessage();
      });
    }
    .width('100%')
    .padding({ left: CommonConstants.PUBLIC_SPACE, right: CommonConstants.PUBLIC_SPACE, bottom: 20 });
  }

  private async toggleVoiceInput(): Promise<void> {
    if (this.isListening) {
      await this.speechService.stopListening();
      this.isListening = false;
      this.showVoiceAnimation = false;
    } else {
      this.isListening = true;
      this.showVoiceAnimation = true;
      await this.speechService.startListening();
    }
  }

  async sendMessage() {
    const message = this.inputText.trim();
    if (!message || this.isLoading) {
      return;
    }

    this.inputText = '';
    this.showRecommendations = false;

    const userMessage: ChatMessage = {
      id: 'user-' + Date.now(),
      role: 'user',
      content: message,
      timestamp: Date.now(),
      type: 'text'
    };
    this.messages.push(userMessage);

    this.isLoading = true;

    try {
      await this.recommendService.initialize();
      const response = await this.recommendService.chat(message);

      const assistantMessage: ChatMessage = {
        id: 'assistant-' + Date.now(),
        role: 'assistant',
        content: response.content,
        timestamp: Date.now(),
        type: 'text'
      };
      this.messages.push(assistantMessage);
    } catch (error) {
      const errorMessage: ChatMessage = {
        id: 'assistant-' + Date.now(),
        role: 'assistant',
        content: '抱歉，我暂时无法回答这个问题，请稍后重试',
        timestamp: Date.now(),
        type: 'text'
      };
      this.messages.push(errorMessage);
    } finally {
      this.isLoading = false;
    }
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    return `${hours}:${minutes}`;
  }
}