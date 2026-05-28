import http from '@ohos.net.http';
import type {
  UserPreferences,
  RecommendResult,
  Question,
  AICarRecommendation,
  VolcengineMessage,
  VolcengineRequest,
  VolcengineResponse,
  AIResponseContent,
  ChatResponse
} from '../model/AICarModel';

interface BudgetRange {
  min: number;
  max: number;
}

interface ValidationResult {
  isValid: boolean;
  errorMessage?: string;
}

export class AICarRecommendService {
  private static instance: AICarRecommendService;
  private questions: Question[] = [];
  private isInitialized = false;

  // 火山方舟API配置
  private readonly AI_API_URL = 'https://ark.cn-beijing.volces.com/api/v3/chat/completions';
  private readonly API_KEY = 'ark-5a920e71-a107-4956-99ca-c090c52a7811-5efaf'; // 您的API Key
  private readonly MODEL_ID = 'doubao-seed-2-0-mini-260428'; // 替换为您实际部署的模型ID

  private constructor() {}

  public static getInstance(): AICarRecommendService {
    if (!AICarRecommendService.instance) {
      AICarRecommendService.instance = new AICarRecommendService();
    }
    return AICarRecommendService.instance;
  }

  public async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }
    this.loadQuestions();
    this.isInitialized = true;
  }

  private loadQuestions(): void {
    this.questions = [
      {
        id: 'q1',
        question: '您的购车预算是多少？',
        type: 'range',
        options: [
          { label: '15万以下', min: 0, max: 150000 },
          { label: '15-25万', min: 150000, max: 250000 },
          { label: '25-35万', min: 250000, max: 350000 },
          { label: '35万以上', min: 350000, max: 1000000 }
        ]
      },
      {
        id: 'q2',
        question: '您期望的续航里程是多少？',
        type: 'single',
        options: [
          { label: '400公里以下', value: 400 },
          { label: '400-500公里', value: 450 },
          { label: '500-600公里', value: 550 },
          { label: '600公里以上', value: 600 }
        ]
      },
      {
        id: 'q3',
        question: '您偏好什么类型的车型？',
        type: 'single',
        options: [
          { label: '轿车', value: '轿车' },
          { label: 'SUV', value: 'SUV' },
          { label: 'MPV', value: 'MPV' },
          { label: '无所谓', value: 'any' }
        ]
      },
      {
        id: 'q4',
        question: '您偏好什么动力类型？',
        type: 'single',
        options: [
          { label: '纯电动', value: '纯电动' },
          { label: '增程式', value: '增程式' },
          { label: '混合动力', value: '混合动力' },
          { label: '无所谓', value: 'any' }
        ]
      },
      {
        id: 'q5',
        question: '请用自然语言描述您的其他需求',
        type: 'text',
        placeholder: '例如：我需要一辆适合家庭使用的车，空间要大，最好有自动驾驶功能，安全性要好...'
      }
    ];
  }

  public getQuestions(): Question[] {
    return this.questions;
  }

  /**
   * 验证自然语言输入
   * @param input 用户输入的自然语言描述
   * @returns 验证结果
   */
  public validateNaturalLanguageInput(input: string): ValidationResult {
    const trimmedInput = input.trim();

    if (trimmedInput.length === 0) {
      return { isValid: true };
    }

    if (trimmedInput.length < 5) {
      return {
        isValid: false,
        errorMessage: '输入内容过短，请提供更详细的需求描述'
      };
    }

    const invalidPatterns = [
      /^[\s\p{P}]+$/u,
      /^(哈哈|呵呵|嘿嘿|无语|随便|不知道)$/
    ];

    for (const pattern of invalidPatterns) {
      if (pattern.test(trimmedInput)) {
        return {
          isValid: false,
          errorMessage: '请输入有效的购车需求描述'
        };
      }
    }

    const carRelatedKeywords = [
      '车', '汽车', 'SUV', '轿车', 'MPV', '续航', '电池', '充电',
      '空间', '座位', '加速', '安全', '智能', '自动驾驶', '价格',
      '预算', '配置', '外观', '内饰', '动力', '油耗', '新能源'
    ];

    const containsKeyword = carRelatedKeywords.some(keyword =>
    trimmedInput.includes(keyword)
    );

    if (!containsKeyword && trimmedInput.length < 15) {
      return {
        isValid: false,
        errorMessage: '请输入与购车相关的需求描述，如：空间大、续航长、安全配置高等'
      };
    }

    return { isValid: true };
  }

  /**
   * 计算单辆车的匹配度
   * @param car 推荐的车辆
   * @param preferences 用户偏好
   * @returns 匹配度分数 (0-100)
   */
  private calculateMatchScore(car: AICarRecommendation, preferences: UserPreferences): number {
    let score = 0;
    let weightSum = 0;

    if (preferences.budgetMin >= 0 && preferences.budgetMax >= 0) {
      const carPrice = this.parsePrice(car.price);
      const budgetMid = (preferences.budgetMin + preferences.budgetMax) / 2;
      const budgetRange = preferences.budgetMax - preferences.budgetMin;

      if (carPrice >= preferences.budgetMin && carPrice <= preferences.budgetMax) {
        const distanceFromMid = Math.abs(carPrice - budgetMid);
        const normalizedDistance = distanceFromMid / (budgetRange / 2);
        score += (1 - normalizedDistance) * 30;
      } else {
        const overBudget = carPrice > preferences.budgetMax;
        const ratio = overBudget
          ? (carPrice - preferences.budgetMax) / preferences.budgetMax
          : (preferences.budgetMin - carPrice) / preferences.budgetMin;
        score += Math.max(0, (1 - ratio * 2) * 15);
      }
      weightSum += 30;
    }

    if (preferences.rangeRequirement > 0) {
      const carRange = this.parseRange(car.range);
      if (carRange >= preferences.rangeRequirement) {
        score += 25;
      } else {
        const ratio = carRange / preferences.rangeRequirement;
        score += ratio * 25;
      }
      weightSum += 25;
    }

    if (preferences.bodyType && preferences.bodyType !== 'any') {
      if (car.bodyType === preferences.bodyType) {
        score += 20;
      } else if (car.bodyType.includes(preferences.bodyType) || preferences.bodyType.includes(car.bodyType)) {
        score += 10;
      }
      weightSum += 20;
    }

    if (preferences.powerType && preferences.powerType !== 'any') {
      if (car.powerType === preferences.powerType) {
        score += 15;
      } else if (preferences.powerType === '混合动力' && (car.powerType === '增程式' || car.powerType === '纯电动')) {
        score += 7;
      } else if (preferences.powerType === '增程式' && car.powerType === '混合动力') {
        score += 7;
      }
      weightSum += 15;
    }

    if (preferences.naturalLanguageDescription && preferences.naturalLanguageDescription.trim().length > 0) {
      const desc = preferences.naturalLanguageDescription;
      let featureMatch = 0;
      let totalChecked = 0;

      const featureKeywords: Record<string, string[]> = {
        '自动驾驶': ['自动', '驾驶', '辅助'],
        '全景天窗': ['天窗', '全景'],
        '座椅加热': ['加热', '座椅'],
        '空间': ['空间', '大', '宽敞'],
        '安全': ['安全', '碰撞', '气囊'],
        '加速': ['加速', '秒', '快']
      };

      if (car.keyFeatures) {
        for (const feature of car.keyFeatures) {
          const keywords = featureKeywords[feature] || [feature];
          totalChecked++;
          if (keywords.some(keyword => desc.includes(keyword))) {
            featureMatch++;
          }
        }
      }

      if (totalChecked > 0) {
        score += (featureMatch / totalChecked) * 10;
      } else {
        score += 5;
      }
      weightSum += 10;
    }

    if (weightSum > 0) {
      score = (score / weightSum) * 100;
    } else {
      score = 50;
    }

    return Math.round(Math.max(0, Math.min(100, score)));
  }

  private parsePrice(priceStr: string): number {
    const match = priceStr.match(/([\d.]+)/);
    return match ? parseFloat(match[1]) * 10000 : 0;
  }

  private parseRange(rangeStr: string): number {
    const match = rangeStr.match(/([\d.]+)/);
    return match ? parseFloat(match[1]) : 0;
  }

  /**
   * 调用火山方舟大模型API进行推荐
   * @param preferences 用户偏好
   * @returns 推荐结果
   */
  public async recommend(preferences: UserPreferences): Promise<RecommendResult[]> {
    try {
      // 构建系统提示词
      const systemPrompt = `你是一位专业的汽车推荐顾问。请根据用户提供的购车需求，推荐3款最合适的新能源汽车。

要求：
1. 严格按照以下JSON格式返回结果，不要添加任何额外的文字说明
2. 推荐3款当前市场上真实存在的新能源汽车
3. 每款车的信息要准确，包括品牌、型号、价格、续航、动力类型、车型、座位数、加速时间、主要配置和推荐理由
4. image字段请使用以下值之一：brand_car1, brand_car3

返回格式示例：
{
  "recommendations": [
    {
      "brand": "比亚迪",
      "model": "汉EV",
      "price": "25.98万",
      "range": "605公里",
      "powerType": "纯电动",
      "bodyType": "轿车",
      "seatCount": "5座",
      "acceleration": "3.9秒",
      "keyFeatures": ["自动驾驶", "全景天窗", "座椅加热", "DiLink系统"],
      "matchReason": "比亚迪旗舰电动轿车，搭载刀片电池技术，安全性高",
      "image": "brand_car1"
    }
  ]
}`;

      // 构建用户提示词
      const userPrompt = `我的购车需求：
- 预算：${preferences.budgetMin / 10000}-${preferences.budgetMax / 10000}万
- 期望续航：${preferences.rangeRequirement}公里以上
- 车型偏好：${preferences.bodyType === 'any' ? '不限' : preferences.bodyType}
- 动力类型偏好：${preferences.powerType === 'any' ? '不限' : preferences.powerType}
- 其他需求：${preferences.naturalLanguageDescription || '无特殊要求'}

请根据以上需求推荐3款最合适的新能源汽车。`;

      // 构建API请求
      const request: VolcengineRequest = {
        model: this.MODEL_ID,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        temperature: 0.7,
        max_tokens: 2000,
      };

      // 调用火山方舟API（使用官方http模块）
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(this.AI_API_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.API_KEY}`
        },
        extraData: JSON.stringify(request)
      });

      httpRequest.destroy();

      if (response.responseCode !== 200) {
        throw new Error(`API请求失败: ${response.responseCode}`);
      }

      const aiResponse: VolcengineResponse = JSON.parse(response.result as string);

      if (aiResponse.error) {
        throw new Error(`API错误: ${aiResponse.error.message}`);
      }

      if (!aiResponse.choices || aiResponse.choices.length === 0) {
        throw new Error('API返回空结果');
      }

      // 解析AI返回的JSON
      const content = aiResponse.choices[0].message.content;
      const parsedResult = JSON.parse(content) as AIResponseContent;

      if (!parsedResult.recommendations || !Array.isArray(parsedResult.recommendations)) {
        throw new Error('API返回格式不正确');
      }

      // 转换为推荐结果格式（传入用户偏好用于计算匹配度）
      return this.convertAIResponseToResults(parsedResult.recommendations, preferences);
    } catch (error) {
      console.error('AI推荐出错:', error);
      // 直接抛出错误，让UI层处理，不再返回默认结果
      if (error instanceof Error) {
        throw error;
      } else {
        throw new Error(`未知错误: ${String(error)}`);
      }
    }
  }

  /**
   * 转换AI响应为推荐结果格式
   * @param aiRecommendations AI返回的推荐列表
   * @param preferences 用户偏好（用于计算匹配度）
   */
  private convertAIResponseToResults(aiRecommendations: AICarRecommendation[], preferences: UserPreferences): RecommendResult[] {
    const results = aiRecommendations.map((car) => {
      const score = this.calculateMatchScore(car, preferences);
      const reasons: string[] = [];

      if (car.matchReason) {
        reasons.push(car.matchReason);
      }

      const carPrice = this.parsePrice(car.price);
      if (preferences.budgetMin >= 0 && preferences.budgetMax >= 0) {
        if (carPrice >= preferences.budgetMin && carPrice <= preferences.budgetMax) {
          reasons.push(`价格在您的预算范围内`);
        } else {
          reasons.push(`价格略超出您的预算范围`);
        }
      }

      const carRange = this.parseRange(car.range);
      if (preferences.rangeRequirement > 0) {
        if (carRange >= preferences.rangeRequirement) {
          reasons.push(`续航里程满足需求`);
        } else {
          reasons.push(`续航里程接近您的期望`);
        }
      }

      if (preferences.bodyType && preferences.bodyType !== 'any' && car.bodyType === preferences.bodyType) {
        reasons.push(`符合您偏好的${preferences.bodyType}车型`);
      }

      if (preferences.powerType && preferences.powerType !== 'any' && car.powerType === preferences.powerType) {
        reasons.push(`符合您偏好的${preferences.powerType}动力类型`);
      }

      const result: RecommendResult = {
        car: car,
        score: score,
        reasons: reasons.slice(0, 3)
      };
      return result;
    });

    results.sort((a, b) => b.score - a.score);

    return results;
  }

  /**
   * 快速推荐（保留接口兼容）
   */
  public async quickRecommend(budgetLevel: string, bodyType: string = 'any'): Promise<RecommendResult[]> {
    const budgetMap: Record<string, BudgetRange> = {
      'low': { min: 0, max: 150000 },
      'medium': { min: 150000, max: 250000 },
      'high': { min: 250000, max: 350000 },
      'premium': { min: 350000, max: 1000000 }
    };

    const defaultBudget: BudgetRange = { min: 0, max: 1000000 };
    const budget = budgetMap[budgetLevel] || defaultBudget;

    const preferences: UserPreferences = {
      budgetMin: budget.min,
      budgetMax: budget.max,
      rangeRequirement: 400,
      bodyType: bodyType,
      powerType: 'any',
      naturalLanguageDescription: ''
    };

    return this.recommend(preferences);
  }

  /**
   * 智能对话助手 - 支持自然语言对话
   * @param userMessage 用户消息
   * @param context 对话上下文（可选）
   * @returns 对话响应
   */
  public async chat(userMessage: string, context?: string): Promise<ChatResponse> {
    try {
      const systemPrompt = `你是一位专业的汽车推荐顾问小助手。请用自然、友好的语言与用户交流。

职责：
1. 回答用户关于汽车的问题
2. 根据用户需求推荐合适的车型

规则：
1. 如果用户的问题是关于汽车知识（如技术、品牌、保养等），直接用自然语言回答
2. 如果用户表达了购车需求（如预算、偏好、用途等），请用自然语言推荐3款合适的车型，包括品牌、型号、价格、主要特点和推荐理由
3. 不要使用任何JSON格式，只用纯文本回复
4. 如果无法回答或不确定，诚实地告诉用户

示例：
用户：推荐一款20万左右的家用SUV
助手：好的，我来帮您推荐几款20万左右的家用SUV：

1. 比亚迪宋PLUS EV：售价16.98-23.98万，续航可达520公里，空间宽敞，配置丰富，适合家庭使用。

2. 小鹏G6：售价20.99-27.69万，拥有800V超快充技术，智能化配置高，续航可达700公里。

3. 特斯拉Model Y：售价26.39-36.39万，品牌口碑好，自动驾驶功能强大，适合注重科技感的用户。

用户：纯电动车冬天续航会下降多少？
助手：纯电动车在冬季低温环境下，续航通常会下降20%-40%，具体取决于气温和使用条件。`;

      const userPrompt = context ? `${context}\n\n用户：${userMessage}` : userMessage;

      const request: VolcengineRequest = {
        model: this.MODEL_ID,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        temperature: 0.7,
        max_tokens: 3000,
      };

      const httpRequest = http.createHttp();
      const response = await httpRequest.request(this.AI_API_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.API_KEY}`
        },
        extraData: JSON.stringify(request)
      });

      httpRequest.destroy();

      if (response.responseCode !== 200) {
        throw new Error(`API请求失败: ${response.responseCode}`);
      }

      const aiResponse: VolcengineResponse = JSON.parse(response.result as string);

      if (aiResponse.error) {
        throw new Error(`API错误: ${aiResponse.error.message}`);
      }

      if (!aiResponse.choices || aiResponse.choices.length === 0) {
        throw new Error('API返回空结果');
      }

      const content = aiResponse.choices[0].message.content;

      const jsonMatch = content.match(/---\s*(\{[\s\S]*\})\s*---/);
      if (jsonMatch) {
        try {
          const parsedResult = JSON.parse(jsonMatch[1]) as AIResponseContent;
          const textContent = content.split('---')[0].trim();
          
          return {
            success: true,
            message: 'success',
            content: textContent || '已为您找到合适的车型推荐',
            recommendations: parsedResult.recommendations
          };
        } catch {
          return {
            success: true,
            message: 'success',
            content: content
          };
        }
      }

      return {
        success: true,
        message: 'success',
        content: content
      };
    } catch (error) {
      console.error('AI对话出错:', error);
      if (error instanceof Error) {
        return {
          success: false,
          message: error.message,
          content: '抱歉，我暂时无法回答这个问题，请稍后重试'
        };
      } else {
        return {
          success: false,
          message: String(error),
          content: '抱歉，我暂时无法回答这个问题，请稍后重试'
        };
      }
    }
  }
}