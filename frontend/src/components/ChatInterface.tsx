// components/ChatInterface.tsx
'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import { useAuth } from './AuthProvider';
import ReactMarkdown from 'react-markdown';

interface Message {
  role: 'user' | 'assistant' | 'error';
  content: string;
  timestamp: Date;
  model?: string;
  processing_time?: number;
}

interface Model {
  name: string;
  size: number;
  modified_at?: string;
}

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8081';

export default function ChatInterface() {
  const { accessToken, user } = useAuth();
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [models, setModels] = useState<Model[]>([]);
  const [selectedModel, setSelectedModel] = useState('llama3.1:70b');
  const [error, setError] = useState<string | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  const fetchModels = useCallback(async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/models`, {
        headers: { Authorization: `Bearer ${accessToken}` }
      });
      
      if (response.ok) {
        const data = await response.json();
        setModels(data.models);
        setError(null);
      } else {
        setError('Failed to fetch available models');
      }
    } catch (error) {
      console.error('Failed to fetch models:', error);
      setError('Unable to connect to AI service');
    }
  }, [accessToken]);

  useEffect(() => {
    if (accessToken) {
      fetchModels();
    }
  }, [accessToken, fetchModels]);

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const sendMessage = async () => {
    if (!input.trim() || loading) return;

    const userMessage: Message = {
      role: 'user',
      content: input,
      timestamp: new Date()
    };

    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setLoading(true);
    setError(null);

    try {
      const response = await fetch(`${API_BASE_URL}/chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`
        },
        body: JSON.stringify({
          prompt: input,
          model: selectedModel,
          temperature: 0.7,
          max_tokens: 2048
        })
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || `HTTP error! status: ${response.status}`);
      }

      const data = await response.json();

      const assistantMessage: Message = {
        role: 'assistant',
        content: data.response,
        model: data.model,
        processing_time: data.processing_time,
        timestamp: new Date()
      };

      setMessages(prev => [...prev, assistantMessage]);
    } catch (error) {
      console.error('Chat error:', error);
      const errorMessage: Message = {
        role: 'error',
        content: error instanceof Error ? error.message : 'Sorry, there was an error processing your request. Please try again.',
        timestamp: new Date()
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setLoading(false);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  const clearChat = () => {
    setMessages([]);
  };

  return (
    <div className="max-w-6xl mx-auto h-screen flex flex-col bg-white">
      {/* Header Controls */}
      <div className="border-b bg-gray-50 p-4 flex justify-between items-center flex-wrap gap-4">
        <div className="flex items-center space-x-4">
          <select
            value={selectedModel}
            onChange={(e) => setSelectedModel(e.target.value)}
            className="border rounded-lg px-3 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={loading}
          >
            {models.map(model => (
              <option key={model.name} value={model.name}>
                {model.name} {model.size ? `(${Math.round(model.size / 1024 / 1024 / 1024)}GB)` : ''}
              </option>
            ))}
          </select>
          
          <button
            onClick={clearChat}
            className="text-gray-600 hover:text-gray-800 px-3 py-2 rounded-lg hover:bg-gray-200 transition-colors"
            disabled={loading}
          >
            🗑️ Clear Chat
          </button>
        </div>
        
        <div className="text-sm text-gray-600 flex items-center space-x-2">
          <span>👤 {user?.name}</span>
          <span>•</span>
          <span>💬 {messages.filter(m => m.role === 'user').length} messages</span>
        </div>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 p-4 mx-4 mt-4 rounded-lg">
          <p className="text-red-600 text-sm">{error}</p>
        </div>
      )}

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-6 space-y-6">
        {messages.length === 0 && (
          <div className="text-center text-gray-500 mt-12">
            <div className="text-6xl mb-4">🤖</div>
            <h3 className="text-xl font-semibold mb-2">Welcome to Company AI Assistant</h3>
            <p>Ask me anything! I&apos;m powered by {selectedModel} and ready to help.</p>
          </div>
        )}

        {messages.map((message, index) => (
          <div
            key={index}
            className={`flex ${message.role === 'user' ? 'justify-end' : 'justify-start'}`}
          >
            <div className={`max-w-4xl rounded-lg p-4 ${
              message.role === 'user'
                ? 'bg-blue-600 text-white ml-12'
                : message.role === 'error'
                ? 'bg-red-100 text-red-800 mr-12'
                : 'bg-gray-100 text-gray-800 mr-12'
            }`}>
              <div className="flex justify-between items-center mb-2">
                <span className="font-semibold text-sm">
                  {message.role === 'user' ? '👤 You' : message.role === 'error' ? '⚠️ Error' : '🤖 AI Assistant'}
                </span>
                <div className="text-xs opacity-75 flex items-center space-x-2">
                  <span>{message.timestamp.toLocaleTimeString()}</span>
                  {message.processing_time && (
                    <span>⚡ {message.processing_time.toFixed(2)}s</span>
                  )}
                  {message.model && (
                    <span>🧠 {message.model}</span>
                  )}
                </div>
              </div>
              
              <div className={`prose max-w-none ${message.role === 'user' ? 'prose-invert' : ''}`}>
                {message.role === 'assistant' ? (
                  <ReactMarkdown 
                    components={{
                      code: ({ children, className, ...props }) => {
                        const isInline = !className || !className.includes('language-');
                        return (
                          <code 
                            className={`${isInline 
                              ? message.role === 'user' 
                                ? 'bg-white bg-opacity-20 text-white px-1 py-0.5 rounded text-sm'
                                : 'bg-gray-200 px-1 py-0.5 rounded text-sm' 
                              : 'block bg-gray-800 text-white p-3 rounded-lg overflow-x-auto'
                            }`}
                            {...props}
                          >
                            {children}
                          </code>
                        );
                      },
                      pre: ({ children }) => (
                        <pre className="bg-gray-800 text-white p-3 rounded-lg overflow-x-auto">
                          {children}
                        </pre>
                      )
                    }}
                  >
                    {message.content}
                  </ReactMarkdown>
                ) : (
                  <p className="whitespace-pre-wrap">{message.content}</p>
                )}
              </div>
            </div>
          </div>
        ))}
        
        {loading && (
          <div className="flex justify-start">
            <div className="bg-gray-100 rounded-lg p-4 max-w-4xl mr-12">
              <div className="flex items-center space-x-3">
                <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-blue-600"></div>
                <span className="text-gray-600">AI is thinking...</span>
                <div className="text-xs text-gray-400">Using {selectedModel}</div>
              </div>
            </div>
          </div>
        )}
        
        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <div className="border-t bg-gray-50 p-4">
        <div className="flex space-x-4">
          <textarea
            ref={inputRef}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="Ask me anything... (Press Enter to send, Shift+Enter for new line)"
            rows={3}
            disabled={loading}
            className="flex-1 border rounded-lg px-4 py-3 resize-none focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
          <button
            onClick={sendMessage}
            disabled={loading || !input.trim()}
            className="bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white px-8 py-3 rounded-lg transition-colors font-medium min-w-[100px]"
          >
            {loading ? (
              <div className="flex items-center justify-center">
                <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
              </div>
            ) : (
              '📤 Send'
            )}
          </button>
        </div>
        
        <div className="text-xs text-gray-500 mt-2 text-center">
          Powered by Ollama • Enterprise AI Assistant • Your data stays private
        </div>
      </div>
    </div>
  );
}