export interface SpeechRecognitionResult {
  success: boolean;
  text?: string;
  error?: string;
}

export interface SpeechRecognitionListener {
  onResult?: (result: string) => void;
  onError?: (error: string) => void;
  onStateChange?: (state: 'idle' | 'listening' | 'recognizing' | 'finished') => void;
}

export class SpeechRecognitionService {
  private static instance: SpeechRecognitionService;
  private listener: SpeechRecognitionListener | null = null;
  private isListening: boolean = false;
  private simulateTimer: number | null = null;

  private constructor() {}

  public static getInstance(): SpeechRecognitionService {
    if (!SpeechRecognitionService.instance) {
      SpeechRecognitionService.instance = new SpeechRecognitionService();
    }
    return SpeechRecognitionService.instance;
  }

  public setListener(listener: SpeechRecognitionListener): void {
    this.listener = listener;
  }

  public async startListening(): Promise<void> {
    if (this.isListening) {
      return;
    }

    this.isListening = true;
    this.notifyStateChange('listening');

    try {
      const mockResults: string[] = [
        '推荐一款20万左右的SUV',
        '纯电动车冬天续航会下降多少',
        '比亚迪汉EV怎么样',
        '帮我对比一下特斯拉和小鹏',
        '我需要一辆适合家庭使用的车'
      ];

      this.simulateTimer = setTimeout(() => {
        const randomResult = mockResults[Math.floor(Math.random() * mockResults.length)];
        if (this.listener?.onResult) {
          this.listener.onResult(randomResult);
        }
        this.stopListening();
      }, 2000);
    } catch (error) {
      this.isListening = false;
      this.notifyStateChange('finished');
      if (this.listener?.onError) {
        this.listener.onError(`启动语音识别失败: ${String(error)}`);
      }
    }
  }

  public async stopListening(): Promise<void> {
    if (!this.isListening) {
      return;
    }

    if (this.simulateTimer) {
      clearTimeout(this.simulateTimer);
      this.simulateTimer = null;
    }

    this.isListening = false;
    this.notifyStateChange('finished');
  }

  public isListeningNow(): boolean {
    return this.isListening;
  }

  private notifyStateChange(state: 'idle' | 'listening' | 'recognizing' | 'finished'): void {
    if (this.listener?.onStateChange) {
      this.listener.onStateChange(state);
    }
  }
}