// components/AuthProvider.tsx
'use client';

import React, { createContext, useContext, useState, useEffect } from 'react';
import { PublicClientApplication, AccountInfo } from '@azure/msal-browser';
import { MsalProvider } from '@azure/msal-react';

const msalConfig = {
  auth: {
    clientId: process.env.NEXT_PUBLIC_AZURE_CLIENT_ID!,
    authority: `https://login.microsoftonline.com/${process.env.NEXT_PUBLIC_AZURE_TENANT_ID}`,
    redirectUri: typeof window !== 'undefined' ? window.location.origin : '',
  },
  cache: {
    cacheLocation: 'localStorage' as const,
    storeAuthStateInCookie: false,
  }
};

const msalInstance = new PublicClientApplication(msalConfig);

interface AuthContextType {
  isAuthenticated: boolean;
  user: AccountInfo | null;
  accessToken: string | null;
  login: () => Promise<void>;
  logout: () => void;
  loading: boolean;
  error: string | null;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export default function AuthProvider({ children }: { children: React.ReactNode }) {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [user, setUser] = useState<AccountInfo | null>(null);
  const [accessToken, setAccessToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const initializeAuth = async () => {
      try {
        await msalInstance.initialize();
        const accounts = msalInstance.getAllAccounts();
        
        if (accounts.length > 0) {
          setIsAuthenticated(true);
          setUser(accounts[0]);
          await acquireAccessToken(accounts[0]);
        }
      } catch (err) {
        setError('Failed to initialize authentication');
        console.error('Auth initialization error:', err);
      } finally {
        setLoading(false);
      }
    };

    initializeAuth();
  }, []);

  const acquireAccessToken = async (account: AccountInfo) => {
    const request = {
      scopes: ['https://graph.microsoft.com/User.Read'],
      account: account,
    };

    try {
      const response = await msalInstance.acquireTokenSilent(request);
      setAccessToken(response.accessToken);
      setError(null);
    } catch (error) {
      console.error('Silent token acquisition failed:', error);
      try {
        const response = await msalInstance.acquireTokenPopup(request);
        setAccessToken(response.accessToken);
        setError(null);
      } catch (popupError) {
        console.error('Interactive token acquisition failed:', popupError);
        setError('Failed to acquire access token');
      }
    }
  };

  const login = async () => {
    try {
      setError(null);
      const response = await msalInstance.loginPopup({
        scopes: ['https://graph.microsoft.com/User.Read'],
      });
      
      setIsAuthenticated(true);
      setUser(response.account);
      setAccessToken(response.accessToken);
    } catch (error) {
      console.error('Login failed:', error);
      setError('Login failed. Please try again.');
    }
  };

  const logout = () => {
    msalInstance.logoutPopup();
    setIsAuthenticated(false);
    setUser(null);
    setAccessToken(null);
    setError(null);
  };

  return (
    <MsalProvider instance={msalInstance}>
      <AuthContext.Provider value={{
        isAuthenticated,
        user,
        accessToken,
        login,
        logout,
        loading,
        error
      }}>
        {children}
      </AuthContext.Provider>
    </MsalProvider>
  );
}