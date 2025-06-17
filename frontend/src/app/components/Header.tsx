// components/Header.tsx
'use client';

import { useAuth } from './AuthProvider';

export default function Header() {
  const { isAuthenticated, user, logout, error } = useAuth();

  return (
    <header className="bg-blue-600 text-white shadow-lg">
      <div className="container mx-auto px-4 py-4 flex justify-between items-center">
        <h1 className="text-2xl font-bold">🤖 Company AI Assistant</h1>
        
        <div className="flex items-center space-x-4">
          {error && (
            <div className="text-red-200 text-sm bg-red-500 bg-opacity-50 px-3 py-1 rounded">
              {error}
            </div>
          )}
          
          {isAuthenticated && user && (
            <>
              <div className="text-sm">
                <div className="font-medium">{user.name || user.username}</div>
                <div className="text-blue-200 text-xs">{user.username}</div>
              </div>
              <button
                onClick={logout}
                className="bg-blue-700 hover:bg-blue-800 px-4 py-2 rounded transition-colors text-sm"
              >
                Logout
              </button>
            </>
          )}
        </div>
      </div>
    </header>
  );
}