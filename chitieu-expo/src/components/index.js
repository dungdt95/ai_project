import React, { useState, useRef, useEffect } from 'react';
import {
  View, Text, TouchableOpacity, TextInput, StyleSheet, ActivityIndicator,
  Modal, FlatList,
} from 'react-native';
import { COLORS } from '../constants';

// ── Format helpers ────────────────────────────────────────────────────────────
export const fmt = (n) =>
  new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(n);

export const fmtShort = (n) => {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'tr';
  if (n >= 1_000)     return (n / 1_000).toFixed(0) + 'k';
  return String(n);
};

export const fmtDate = (s) =>
  new Date(s).toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit' });

export const fmtDateFull = (s) =>
  new Date(s).toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit', year: 'numeric' });

export const todayStr = () => new Date().toISOString().split('T')[0];

export const daysUntil = (s) =>
  Math.ceil((new Date(s) - new Date(todayStr())) / 86_400_000);

// ── Amount input with thousand separator ──────────────────────────────────────
export function AmountInput({ value, onChange, color = COLORS.accent, placeholder = '0', style }) {
  const display = value
    ? parseInt(value, 10).toLocaleString('vi-VN')
    : '';

  return (
    <TextInput
      value={display}
      onChangeText={(text) => {
        const raw = text.replace(/\./g, '').replace(/,/g, '').replace(/\D/g, '');
        onChange(raw);
      }}
      placeholder={placeholder}
      placeholderTextColor={COLORS.subtext}
      keyboardType="numeric"
      style={[{ color: COLORS.text, fontSize: 30, fontWeight: '800', flex: 1 }, style]}
    />
  );
}

// ── Card ─────────────────────────────────────────────────────────────────────
export function Card({ children, style, borderColor }) {
  return (
    <View style={[styles.card, borderColor && { borderColor }, style]}>
      {children}
    </View>
  );
}

// ── Label ────────────────────────────────────────────────────────────────────
export function Label({ children }) {
  return <Text style={styles.label}>{children}</Text>;
}

// ── BigButton ────────────────────────────────────────────────────────────────
export function BigButton({ label, onPress, active, gradient = ['#E8FF47', '#A8E6CF'] }) {
  return (
    <TouchableOpacity
      onPress={onPress}
      activeOpacity={0.8}
      style={[styles.bigBtn, { backgroundColor: active ? gradient[0] : COLORS.card }]}
    >
      <Text style={[styles.bigBtnText, { color: active ? '#0F0F14' : COLORS.subtext }]}>
        {label}
      </Text>
    </TouchableOpacity>
  );
}

// ── Back button ───────────────────────────────────────────────────────────────
export function BackBtn({ onPress }) {
  return (
    <TouchableOpacity onPress={onPress} style={{ marginBottom: 20 }}>
      <Text style={{ color: COLORS.subtext, fontSize: 28 }}>←</Text>
    </TouchableOpacity>
  );
}

// ── Loading ───────────────────────────────────────────────────────────────────
export function LoadingScreen() {
  return (
    <View style={styles.loading}>
      <Text style={{ fontSize: 40, marginBottom: 12 }}>💸</Text>
      <ActivityIndicator color={COLORS.accent} />
    </View>
  );
}

// ── SummaryRow ────────────────────────────────────────────────────────────────
export function SummaryRow({ label, value, color }) {
  return (
    <View style={styles.row}>
      <Text style={styles.rowLabel}>{label}</Text>
      <Text style={[styles.rowValue, { color }]}>{value}</Text>
    </View>
  );
}

// ── Badge (days indicator) ────────────────────────────────────────────────────
export function DaysBadge({ days }) {
  const over   = days < 0;
  const urgent = !over && days <= 7;
  const bg     = over ? 'rgba(255,107,107,.15)' : urgent ? 'rgba(255,179,71,.15)' : 'rgba(255,255,255,.07)';
  const color  = over ? COLORS.red : urgent ? COLORS.orange : COLORS.subtext;
  const label  = over
    ? `Quá hạn ${Math.abs(days)} ngày`
    : days === 0 ? '⚡ Hôm nay!'
    : `Còn ${days} ngày`;

  return (
    <View style={[styles.badge, { backgroundColor: bg }]}>
      <Text style={[styles.badgeText, { color }]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: COLORS.card,
    borderRadius: 20,
    padding: 18,
    marginBottom: 14,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.05)',
  },
  label: {
    color: COLORS.subtext,
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 1,
    textTransform: 'uppercase',
    marginBottom: 8,
  },
  bigBtn: {
    borderRadius: 20,
    padding: 17,
    alignItems: 'center',
    marginTop: 8,
  },
  bigBtnText: {
    fontSize: 15,
    fontWeight: '800',
    letterSpacing: 1,
  },
  loading: {
    flex: 1,
    backgroundColor: COLORS.bg,
    alignItems: 'center',
    justifyContent: 'center',
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  rowLabel: { color: COLORS.subtext, fontSize: 14 },
  rowValue: { fontSize: 14, fontWeight: '700' },
  badge: {
    borderRadius: 20,
    paddingHorizontal: 12,
    paddingVertical: 5,
  },
  badgeText: { fontSize: 12, fontWeight: '700' },
});

// ── DatePickerModal (pure JS, no native dependency) ───────────────────────────
const ITEM_H  = 48;
const VISIBLE = 5;
const PAD     = ITEM_H * Math.floor(VISIBLE / 2);

function WheelColumn({ items, selected, onSelect, fmtFn, visible }) {
  const flatRef = useRef(null);
  const idx     = items.indexOf(selected);

  useEffect(() => {
    if (!visible) return;
    const t = setTimeout(() => {
      flatRef.current?.scrollToOffset({ offset: Math.max(0, idx) * ITEM_H, animated: false });
    }, 60);
    return () => clearTimeout(t);
  }, [visible, idx]);

  return (
    <View style={{ flex: 1 }}>
      <FlatList
        ref={flatRef}
        data={items}
        keyExtractor={(v) => String(v)}
        showsVerticalScrollIndicator={false}
        snapToInterval={ITEM_H}
        decelerationRate="fast"
        getItemLayout={(_, i) => ({ length: ITEM_H, offset: ITEM_H * i, index: i })}
        style={{ height: ITEM_H * VISIBLE }}
        contentContainerStyle={{ paddingVertical: PAD }}
        onMomentumScrollEnd={(e) => {
          const i = Math.round(e.nativeEvent.contentOffset.y / ITEM_H);
          onSelect(items[Math.max(0, Math.min(i, items.length - 1))]);
        }}
        renderItem={({ item }) => {
          const active = item === selected;
          return (
            <TouchableOpacity onPress={() => onSelect(item)}
              style={{ height: ITEM_H, justifyContent: 'center', alignItems: 'center' }}>
              <Text style={{
                color: active ? COLORS.text : COLORS.subtext,
                fontSize: active ? 20 : 15,
                fontWeight: active ? '800' : '400',
              }}>
                {fmtFn ? fmtFn(item) : String(item).padStart(2, '0')}
              </Text>
            </TouchableOpacity>
          );
        }}
      />
      <View pointerEvents="none" style={[StyleSheet.absoluteFill, { justifyContent: 'center' }]}>
        <View style={{ borderTopWidth: 1, borderBottomWidth: 1, borderColor: 'rgba(255,255,255,0.15)', height: ITEM_H }} />
      </View>
    </View>
  );
}

export function DatePickerModal({ visible, date, onConfirm, onCancel }) {
  const base   = date instanceof Date && !isNaN(date) ? date : new Date();
  const [selYear,  setSelYear]  = useState(base.getFullYear());
  const [selMonth, setSelMonth] = useState(base.getMonth() + 1);
  const [selDay,   setSelDay]   = useState(base.getDate());

  useEffect(() => {
    if (visible) {
      setSelYear(base.getFullYear());
      setSelMonth(base.getMonth() + 1);
      setSelDay(base.getDate());
    }
  }, [visible]);

  const today        = new Date();
  const daysInMonth  = new Date(selYear, selMonth, 0).getDate();
  const days         = Array.from({ length: daysInMonth }, (_, i) => i + 1);
  const months       = Array.from({ length: 12 }, (_, i) => i + 1);
  const years        = Array.from({ length: 10 }, (_, i) => today.getFullYear() - 1 + i);

  const handleConfirm = () => {
    const safeDay = Math.min(selDay, new Date(selYear, selMonth, 0).getDate());
    onConfirm(new Date(selYear, selMonth - 1, safeDay));
  };

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onCancel}>
      <View style={dpStyles.backdrop}>
        <TouchableOpacity style={StyleSheet.absoluteFill} onPress={onCancel} activeOpacity={1} />
        <View style={dpStyles.sheet}>
          <Text style={dpStyles.title}>Chọn ngày</Text>
          <View style={dpStyles.cols}>
            <WheelColumn items={days}   selected={selDay}   onSelect={setSelDay}   visible={visible} />
            <Text style={dpStyles.sep}>/</Text>
            <WheelColumn items={months} selected={selMonth} onSelect={setSelMonth} visible={visible} />
            <Text style={dpStyles.sep}>/</Text>
            <WheelColumn items={years}  selected={selYear}  onSelect={setSelYear}  visible={visible} />
          </View>
          <View style={dpStyles.btnRow}>
            <TouchableOpacity onPress={onCancel} style={dpStyles.cancelBtn}>
              <Text style={{ color: COLORS.subtext, fontWeight: '700', fontSize: 15 }}>Huỷ</Text>
            </TouchableOpacity>
            <TouchableOpacity onPress={handleConfirm} style={dpStyles.okBtn}>
              <Text style={{ color: COLORS.bg, fontWeight: '800', fontSize: 15 }}>Xác nhận</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const dpStyles = StyleSheet.create({
  backdrop:  { flex: 1, backgroundColor: 'rgba(0,0,0,0.65)', justifyContent: 'flex-end' },
  sheet:     { backgroundColor: COLORS.card, borderTopLeftRadius: 24, borderTopRightRadius: 24, padding: 24, paddingBottom: 40 },
  title:     { color: COLORS.text, fontSize: 16, fontWeight: '800', textAlign: 'center', marginBottom: 16 },
  cols:      { flexDirection: 'row', alignItems: 'center' },
  sep:       { color: COLORS.subtext, fontSize: 22, fontWeight: '700', paddingHorizontal: 6 },
  btnRow:    { flexDirection: 'row', gap: 12, marginTop: 20 },
  cancelBtn: { flex: 1, borderRadius: 14, padding: 14, alignItems: 'center', backgroundColor: 'rgba(255,255,255,0.06)' },
  okBtn:     { flex: 2, borderRadius: 14, padding: 14, alignItems: 'center', backgroundColor: COLORS.accent },
});
