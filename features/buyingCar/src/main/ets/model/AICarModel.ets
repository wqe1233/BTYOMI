export interface AICarRecommendation {
  brand: string;
  model: string;
  price: string;
  range: string;
  powerType: string;
  bodyType: string;
  seatCount: string;
  acceleration: string;
  keyFeatures: string[];
  matchReason: string;
  image: string;
}

export interface QuestionOption {
  label: string;
  value?: number | string;
  min?: number;
  max?: number;
}

export interface Question {
  id: string;
  question: string;
  type: string; // 'range' | 'single' | 'text'
  options?: QuestionOption[];
  placeholder?: string;
}

export interface UserPreferences {
  budgetMin: number;
  budgetMax: number;
  rangeRequirement: number;
  bodyType: string;
  powerType: string;
  naturalLanguageDescription: string;
}

export interface RecommendResult {
  car: AICarRecommendation;
  score: number;
  reasons: string[];
}

export interface AIRecommendResponse {
  success: boolean;
  message: string;
  results: RecommendResult[];
  preferences: UserPreferences;
}

// 火山方舟API接口
export interface VolcengineMessage {
  role: string;
  content: string;
}

export interface VolcengineUsage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

export interface VolcengineError {
  message: string;
  type: string;
  code: string;
}

export interface VolcengineChoice {
  message: VolcengineMessage;
  finish_reason: string;
  index: number;
}

export interface VolcengineResponseFormat {
  type: string;
}

export interface VolcengineRequest {
  model: string;
  messages: VolcengineMessage[];
  temperature?: number;
  max_tokens?: number;
  response_format?: VolcengineResponseFormat;
}

export interface VolcengineResponse {
  id: string;
  object: string;
  created: number;
  model: string;
  choices: VolcengineChoice[];
  usage: VolcengineUsage;
  error?: VolcengineError;
}
export interface AIResponseContent {
  recommendations: AICarRecommendation[];
}

export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
  type: 'text' | 'recommendation';
  recommendations?: RecommendResult[];
}

export interface ChatResponse {
  success: boolean;
  message: string;
  content: string;
  recommendations?: AICarRecommendation[];
}