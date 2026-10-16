import React from 'react';
import {
  View, Text, ScrollView, TouchableOpacity, StyleSheet,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useApp } from '../storage/AppContext';
import { COLORS, CATEGORIES, INCOME_SOURCES } from '../constants';
import { fmt, fmtShort, fmtDate, todayStr } from '../components';

export default function HomeScreen({ navigation }) {
  const insets = useSafeAreaInsets();
  const { txs, incomes, deposits, loans, budget } = useApp();

  const totalSpent  = txs.reduce((s, t) => s + t.amount, 0);
  const totalIncome = incomes.reduce((s, i) => s + i.amount, 0);
  const balance     = totalIncome - totalSpent;
  const progress    = budget ? Math.min((totalSpent / budget) * 100, 100) : 0;
  const todaySpent  = txs.filter(t => t.date === todayStr()).reduce((s, t) => s + t.amount, 0);
  const totalDeposited = deposits.reduce((s, d) => s + d.amount, 0);
  const totalLoaned    = loans.filter(l => !l.paid).reduce((s, l) => s + l.amount, 0);

  const catTotals = CATEGORIES
    .map(c => ({ ...c, total: txs.filter(t => t.category === c.id).reduce((s, t) => s + t.amount, 0) }))
    .filter(c => c.total > 0).sort((a, b) => b.total - a.total);

  // Merged feed
  const feed = [
    ...txs.map(t => ({ ...t, kind: 'expense' })),
    ...incomes.map(i => ({ ...i, kind: 'income' })),
  ].sort((a, b) => new Date(b.date) - new Date(a.date) || b.id - a.id).slice(0, 20);

  const feedByDate = feed.reduce((acc, item) => {
    (acc[item.date] = acc[item.date] || []).push(item);
    return acc;
  }, {});

  return (
    <ScrollView style={styles.container} contentContainerStyle={{ paddingBottom: 100 }} showsVerticalScrollIndicator={false}>
      {/* Header */}
      <LinearGradient colors={['#1A1A2E', '#16213E']} style={[styles.header, { paddingTop: insets.top + 20 }]}>
        <View style={{ position: 'absolute', top: -60, right: -60, width: 200, height: 200, borderRadius: 100, backgroundColor: 'rgba(232,255,71,0.05)' }} />

        <View style={styles.headerRow}>
          <View style={{ flex: 1 }}>
            <Text style={styles.monthLabel}>
              {new Date().toLocaleDateString('vi-VN', { month: 'long', year: 'numeric' }).toUpperCase()}
            </Text>
            <Text style={styles.balanceAmount}>
              {fmt(Math.abs(balance)).replace('₫', '')}
              <Text style={{ fontSize: 20, color: balance >= 0 ? COLORS.green : COLORS.red }}> ₫</Text>
            </Text>
            <Text style={styles.balanceSub}>{balance >= 0 ? '💰 Số dư khả dụng' : '⚠️ Bội chi'}</Text>
          </View>
          <TouchableOpacity onPress={() => navigation.navigate('Budget')} style={styles.todayCard}>
            <Text style={styles.todayLabel}>HÔM NAY</Text>
            <Text style={styles.todayValue}>{fmtShort(todaySpent)} ₫</Text>
          </TouchableOpacity>
        </View>

        {/* Budget bar */}
        <View style={{ marginTop: 18 }}>
          <View style={styles.barRow}>
            <Text style={styles.barLabel}>Chi tiêu / Ngân sách</Text>
            <Text style={styles.barLabel}>{budget ? Math.round(progress) + '%' : 'Chưa đặt'}</Text>
          </View>
          <View style={styles.barTrack}>
            <View style={[styles.barFill, {
              width: `${progress}%`,
              backgroundColor: progress > 80 ? COLORS.red : COLORS.accent,
            }]} />
          </View>
        </View>

        {/* Income / Expense cards */}
        <View style={styles.summaryRow}>
          {[
            { label: '↑ THU NHẬP', v: totalIncome, color: COLORS.green, bg: 'rgba(168,230,207,0.08)', bo: 'rgba(168,230,207,0.14)' },
            { label: '↓ CHI TIÊU', v: totalSpent,  color: COLORS.redLight, bg: 'rgba(255,107,107,0.08)', bo: 'rgba(255,107,107,0.14)' },
          ].map(x => (
            <View key={x.label} style={[styles.summaryCard, { backgroundColor: x.bg, borderColor: x.bo }]}>
              <Text style={[styles.summaryCardLabel, { color: x.color }]}>{x.label}</Text>
              <Text style={styles.summaryCardValue}>{(x.v / 1_000_000).toFixed(2)}tr ₫</Text>
            </View>
          ))}
        </View>
      </LinearGradient>

      {/* Bank teaser */}
      <TouchableOpacity onPress={() => navigation.navigate('Bank')} style={styles.teaser}>
        <View style={styles.teaserLeft}>
          <Text style={{ fontSize: 22 }}>🏦</Text>
          <View style={{ marginLeft: 12 }}>
            <Text style={styles.teaserLabel}>Tiền gửi ngân hàng</Text>
            <Text style={styles.teaserValue}>{deposits.length > 0 ? fmt(totalDeposited) : 'Chưa có khoản gửi'}</Text>
          </View>
        </View>
        <Text style={{ color: COLORS.subtext, fontSize: 20 }}>›</Text>
      </TouchableOpacity>

      {/* Loan teaser */}
      <TouchableOpacity onPress={() => navigation.navigate('Loans')}
        style={[styles.teaser, { borderColor: totalLoaned > 0 ? 'rgba(255,179,71,0.2)' : COLORS.border }]}>
        <View style={styles.teaserLeft}>
          <Text style={{ fontSize: 22 }}>🤝</Text>
          <View style={{ marginLeft: 12 }}>
            <Text style={styles.teaserLabel}>Cho vay</Text>
            <Text style={[styles.teaserValue, { color: totalLoaned > 0 ? COLORS.orange : COLORS.text }]}>
              {totalLoaned > 0 ? `${fmt(totalLoaned)} chưa thu` : 'Không có khoản nào'}
            </Text>
          </View>
        </View>
        <Text style={{ color: COLORS.subtext, fontSize: 20 }}>›</Text>
      </TouchableOpacity>

      {/* Top categories */}
      {catTotals.length > 0 && (
        <View style={styles.catRow}>
          {catTotals.slice(0, 3).map(c => (
            <View key={c.id} style={styles.catCard}>
              <Text style={{ fontSize: 22 }}>{c.icon}</Text>
              <Text style={styles.catLabel}>{c.label}</Text>
              <Text style={styles.catValue}>{fmtShort(c.total)}</Text>
            </View>
          ))}
        </View>
      )}

      {/* Feed */}
      <View style={styles.feedSection}>
        <View style={styles.feedHeader}>
          <Text style={styles.feedTitle}>Giao dịch gần đây</Text>
          <TouchableOpacity onPress={() => navigation.navigate('Stats')}>
            <Text style={{ color: COLORS.accent, fontSize: 13 }}>Xem tất cả →</Text>
          </TouchableOpacity>
        </View>

        {Object.keys(feedByDate).length === 0 && (
          <View style={{ alignItems: 'center', paddingVertical: 40 }}>
            <Text style={{ fontSize: 36, marginBottom: 10 }}>🌱</Text>
            <Text style={{ color: COLORS.subtext, fontSize: 14 }}>Chưa có giao dịch nào</Text>
          </View>
        )}

        {Object.entries(feedByDate).map(([date, items]) => {
          const dayNet = items.reduce((s, i) => i.kind === 'income' ? s + i.amount : s - i.amount, 0);
          return (
            <View key={date} style={{ marginBottom: 20 }}>
              <View style={styles.dateRow}>
                <Text style={styles.dateLabel}>{date === todayStr() ? 'Hôm nay' : fmtDate(date)}</Text>
                <Text style={{ color: dayNet >= 0 ? COLORS.green : COLORS.redLight, fontSize: 12, fontWeight: '700' }}>
                  {dayNet >= 0 ? '+' : ''}{fmtShort(dayNet)}
                </Text>
              </View>
              {items.map(item => {
                const isExp = item.kind === 'expense';
                const meta  = isExp
                  ? CATEGORIES.find(c => c.id === item.category)
                  : INCOME_SOURCES.find(s => s.id === item.source);
                return (
                  <View key={item.id} style={[styles.txRow, { borderColor: isExp ? COLORS.border : 'rgba(168,230,207,0.07)' }]}>
                    <View style={[styles.txIcon, { backgroundColor: (meta?.color || '#888') + '22' }]}>
                      <Text style={{ fontSize: 18 }}>{meta?.icon || '💸'}</Text>
                    </View>
                    <View style={{ flex: 1 }}>
                      <Text style={styles.txNote} numberOfLines={1}>{item.note}</Text>
                      <Text style={styles.txSub}>{meta?.label}</Text>
                    </View>
                    <Text style={{ color: isExp ? COLORS.redLight : COLORS.green, fontSize: 14, fontWeight: '700' }}>
                      {isExp ? '-' : '+'}{fmtShort(item.amount)}
                    </Text>
                  </View>
                );
              })}
            </View>
          );
        })}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container:    { flex: 1, backgroundColor: COLORS.bg },
  header:       { padding: 24, paddingBottom: 24 },
  headerRow:    { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  monthLabel:   { color: COLORS.subtext, fontSize: 11, fontWeight: '700', letterSpacing: 1 },
  balanceAmount:{ color: COLORS.text, fontSize: 34, fontWeight: '800', marginTop: 4, lineHeight: 40 },
  balanceSub:   { color: COLORS.subtext, fontSize: 13, marginTop: 5 },
  todayCard:    { backgroundColor: 'rgba(232,255,71,0.08)', borderWidth: 1, borderColor: 'rgba(232,255,71,0.2)', borderRadius: 16, padding: 12, alignItems: 'center', minWidth: 90 },
  todayLabel:   { color: COLORS.accent, fontSize: 10, fontWeight: '700', letterSpacing: 1 },
  todayValue:   { color: COLORS.text, fontSize: 15, fontWeight: '800', marginTop: 3 },
  barRow:       { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 7 },
  barLabel:     { color: COLORS.subtext, fontSize: 12 },
  barTrack:     { backgroundColor: 'rgba(255,255,255,0.07)', borderRadius: 100, height: 6 },
  barFill:      { height: 6, borderRadius: 100 },
  summaryRow:   { flexDirection: 'row', gap: 10, marginTop: 16 },
  summaryCard:  { flex: 1, borderRadius: 14, padding: 12, borderWidth: 1 },
  summaryCardLabel: { fontSize: 10, fontWeight: '700', letterSpacing: 1 },
  summaryCardValue: { color: COLORS.text, fontSize: 15, fontWeight: '800', marginTop: 5 },
  teaser:       { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginHorizontal: 24, marginTop: 14, backgroundColor: COLORS.card, borderWidth: 1, borderColor: 'rgba(195,166,255,0.15)', borderRadius: 18, padding: 14 },
  teaserLeft:   { flexDirection: 'row', alignItems: 'center' },
  teaserLabel:  { color: COLORS.subtext, fontSize: 11, fontWeight: '600' },
  teaserValue:  { color: COLORS.text, fontSize: 15, fontWeight: '800', marginTop: 2 },
  catRow:       { flexDirection: 'row', paddingHorizontal: 24, marginTop: 14, gap: 10 },
  catCard:      { flex: 1, backgroundColor: COLORS.card, borderRadius: 16, padding: 13, borderWidth: 1, borderColor: COLORS.border },
  catLabel:     { color: COLORS.subtext, fontSize: 11, marginTop: 6, fontWeight: '500' },
  catValue:     { color: COLORS.text, fontSize: 13, fontWeight: '700', marginTop: 2 },
  feedSection:  { paddingHorizontal: 24, marginTop: 18 },
  feedHeader:   { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 },
  feedTitle:    { color: COLORS.text, fontSize: 16, fontWeight: '700' },
  dateRow:      { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 10 },
  dateLabel:    { color: COLORS.subtext, fontSize: 11, fontWeight: '700', letterSpacing: 1, textTransform: 'uppercase' },
  txRow:        { flexDirection: 'row', alignItems: 'center', gap: 12, padding: 11, backgroundColor: COLORS.card, borderRadius: 16, marginBottom: 8, borderWidth: 1 },
  txIcon:       { width: 42, height: 42, borderRadius: 13, alignItems: 'center', justifyContent: 'center' },
  txNote:       { fontSize: 14, fontWeight: '600', color: COLORS.text },
  txSub:        { color: COLORS.subtext, fontSize: 12, marginTop: 2 },
});
