import AsyncStorage from '@react-native-async-storage/async-storage';
import { STORAGE_KEY } from '../constants';

export async function loadData() {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw);
  } catch (_) {}
  return null;
}

export async function saveData(data) {
  try {
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  } catch (_) {}
}
