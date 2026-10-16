import 'react-native-gesture-handler';
import React from 'react';
import { StatusBar } from 'expo-status-bar';
import { NavigationContainer, DefaultTheme } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createStackNavigator } from '@react-navigation/stack';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { Text, View } from 'react-native';

import { AppProvider, useApp } from './src/storage/AppContext';
import { COLORS } from './src/constants';
import { LoadingScreen } from './src/components';

import HomeScreen       from './src/screens/HomeScreen';
import AddExpenseScreen from './src/screens/AddExpenseScreen';
import AddIncomeScreen  from './src/screens/AddIncomeScreen';
import BankScreen       from './src/screens/BankScreen';
import LoansScreen      from './src/screens/LoansScreen';
import StatsScreen      from './src/screens/StatsScreen';
import BudgetScreen     from './src/screens/BudgetScreen';

const Tab   = createBottomTabNavigator();
const Stack = createStackNavigator();

const navTheme = {
  ...DefaultTheme,
  colors: { ...DefaultTheme.colors, background: COLORS.bg, card: 'rgba(15,15,20,0.97)', border: COLORS.border, text: COLORS.text },
};

function TabIcon({ emoji, label, focused, hasBadge }) {
  return (
    <View style={{ alignItems: 'center', paddingTop: 6 }}>
      <Text style={{ fontSize: 20, opacity: focused ? 1 : 0.35 }}>{emoji}</Text>
      <Text style={{ color: focused ? COLORS.accent : '#4B5563', fontSize: 10, fontWeight: '700', marginTop: 3 }}>{label}</Text>
      {hasBadge && <View style={{ position: 'absolute', top: 2, right: -4, width: 7, height: 7, borderRadius: 4, backgroundColor: COLORS.orange }} />}
    </View>
  );
}

function Tabs() {
  const { loans } = useApp();
  const hasActiveLoans = loans.some(l => !l.paid);
  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: false,
        tabBarStyle: { backgroundColor: 'rgba(15,15,20,0.97)', borderTopColor: COLORS.border, height: 70, paddingBottom: 8 },
        tabBarShowLabel: false,
      }}>
      <Tab.Screen name="Home"  component={HomeScreen}
        options={{ tabBarIcon: ({ focused }) => <TabIcon emoji="⊞" label="Tổng quan" focused={focused} /> }} />
      <Tab.Screen name="Income" component={AddIncomeScreen}
        options={{ tabBarIcon: ({ focused }) => <TabIcon emoji="↑" label="Nhập tiền" focused={focused} /> }} />
      <Tab.Screen name="AddExpense" component={AddExpenseScreen}
        options={{ tabBarIcon: ({ focused }) => (
          <View style={{ width: 50, height: 50, borderRadius: 25, backgroundColor: '#FF6B6B', alignItems: 'center', justifyContent: 'center', marginBottom: 16, shadowColor: '#FF6B6B', shadowOpacity: 0.5, shadowRadius: 10 }}>
            <Text style={{ color: '#fff', fontSize: 28, lineHeight: 32 }}>−</Text>
          </View>
        )}} />
      <Tab.Screen name="Loans" component={LoansScreen}
        options={{ tabBarIcon: ({ focused }) => <TabIcon emoji="🤝" label="Cho vay" focused={focused} hasBadge={hasActiveLoans} /> }} />
      <Tab.Screen name="Stats" component={StatsScreen}
        options={{ tabBarIcon: ({ focused }) => <TabIcon emoji="◎" label="Thống kê" focused={focused} /> }} />
    </Tab.Navigator>
  );
}

function RootNavigator() {
  const { loading } = useApp();
  if (loading) return <LoadingScreen />;
  return (
    <Stack.Navigator screenOptions={{ headerShown: false, cardStyle: { backgroundColor: COLORS.bg } }}>
      <Stack.Screen name="Tabs"   component={Tabs} />
      <Stack.Screen name="Bank"   component={BankScreen} />
      <Stack.Screen name="Budget" component={BudgetScreen} />
    </Stack.Navigator>
  );
}

export default function App() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <AppProvider>
          <NavigationContainer theme={navTheme}>
            <StatusBar style="light" />
            <RootNavigator />
          </NavigationContainer>
        </AppProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
