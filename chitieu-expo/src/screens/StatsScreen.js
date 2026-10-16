import React, { useState } from 'react';
import { View, Text, ScrollView, TouchableOpacity, StyleSheet } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useApp } from '../storage/AppContext';
import { COLORS, CATEGORIES, INCOME_SOURCES } from '../constants';
import { fmt, fmtShort, fmtDate, SummaryRow, todayStr } from '../components';

export default function StatsScreen({ navigation }) {
  const insets = useSafeAreaInsets();
  const { txs, incomes, deposits, loans, budget } = useApp();
  const [tab,         setTab]         = useState('report');
  const [reportMonth, setReportMonth] = useState(todayStr().slice(0, 7));

  // All-time
  const totalSpent     = txs.reduce((s, t) => s + t.amount, 0);
  const totalIncome    = incomes.reduce((s, i) => s + i.amount, 0);
  const balance        = totalIncome - totalSpent;
  const remaining      = budget != null ? budget - totalSpent : null;
  const totalDeposited = deposits.reduce((s, d) => s + d.amount, 0);
  const totalLoaned    = loans.filter(l => !l.paid).reduce((s, l) => s + l.amount, 0);

  const catTotals = CATEGORIES
    .map(c => ({ ...c, total: txs.filter(t => t.category === c.id).reduce((s, t) => s + t.amount, 0) }))
    .filter(c => c.total > 0).sort((a, b) => b.total - a.total);

  // Monthly
  const goMonth = (dir) => {
    const d = new Date(reportMonth + '-01');
    d.setMonth(d.getMonth() + dir);
    setReportMonth(d.toISOString().slice(0, 7));
  };
  const [rYear, rMonth] = reportMonth.split('-').map(Number);
  const monthTxs    = txs.filter(t => { const d = new Date(t.date); return d.getFullYear() === rYear && d.getMonth() + 1 === rMonth; });
  const monthIncs   = incomes.filter(i => { const d = new Date(i.date); return d.getFullYear() === rYear && d.getMonth() + 1 === rMonth; });
  const mSpent      = monthTxs.reduce((s, t) => s + t.amount, 0);
  const mIncome     = monthIncs.reduce((s, i) => s + i.amount, 0);
  const mBalance    = mIncome - mSpent;
  const monthLabel  = new Date(reportMonth + '-02').toLocaleDateString('vi-VN', { month: 'long', year: 'numeric' });

  const mCatTotals  = CATEGORIES
    .map(c => ({ ...c, total: monthTxs.filter(t => t.category === c.id).reduce((s, t) => s + t.amount, 0) }))
    .filter(c => c.total > 0).sort((a, b) => b.total - a.total);

  const allMonths = [...new Set([
    ...txs.map(t => t.date.slice(0, 7)),
    ...incomes.map(i => i.date.slice(0, 7)),
  ])].sort().reverse();

  const monthFeed = [
    ...monthTxs.map(t => ({ ...t, kind: 'expense' })),
    ...monthIncs.map(i => ({ ...i, kind: 'income' })),
  ].sort((a, b) => new Date(b.date) - new Date(a.date) || b.id - a.id);

  const feedByDate = monthFeed.reduce((acc, item) => {
    (acc[item.date] = acc[item.date] || []).push(item); return acc;
  }, {});

  return (
    <ScrollView style={[styles.container, { paddingTop: insets.top + 20 }]}
      contentContainerStyle={{ padding: 24, paddingBottom: 100 }}
      showsVerticalScrollIndicator={false}>

      {/* Tab switcher */}
      <View style={styles.tabBar}>
        {[{ id: 'report', label: '📅 Theo tháng' }, { id: 'overall', label: '📊 Tổng quan' }].map(t => (
          <TouchableOpacity key={t.id} onPress={() => setTab(t.id)}
            style={[styles.tabBtn, tab === t.id && styles.tabBtnActive]}>
            <Text style={[styles.tabText, { color: tab === t.id ? COLORS.text : COLORS.subtext }]}>{t.label}</Text>
          </TouchableOpacity>
        ))}
      </View>

      {/* ── REPORT TAB ── */}
      {tab === 'report' && (
        <View>
          {/* Month nav */}
          <View style={styles.monthNav}>
            <TouchableOpacity onPress={() => goMonth(-1)} style={styles.navBtn}>
              <Text style={{ color: COLORS.subtext, fontSize: 20 }}>‹</Text>
            </TouchableOpacity>
            <Text style={styles.monthLabel}>{monthLabel}</Text>
            <TouchableOpacity onPress={() => goMonth(1)} style={styles.navBtn}>
              <Text style={{ color: COLORS.subtext, fontSize: 20 }}>›</Text>
            </TouchableOpacity>
          </View>

          {/* Summary cards */}
          <View style={styles.mSummary}>
            {[
              { label: 'THU NHẬP', v: mIncome,  color: COLORS.green,  bg: 'rgba(168,230,207,0.08)', bo: 'rgba(168,230,207,0.15)' },
              { label: 'CHI TIÊU', v: mSpent,   color: COLORS.redLight, bg: 'rgba(255,107,107,0.08)', bo: 'rgba(255,107,107,0.15)' },
              { label: 'SỐ DƯ',   v: mBalance, color: mBalance >= 0 ? COLORS.accent : COLORS.red, bg: mBalance >= 0 ? 'rgba(232,255,71,0.06)' : 'rgba(255,107,107,0.06)', bo: mBalance >= 0 ? 'rgba(232,255,71,0.15)' : 'rgba(255,107,107,0.15)' },
            ].map(x => (
              <View key={x.label} style={[styles.mCard, { backgroundColor: x.bg, borderColor: x.bo }]}>
                <Text style={[styles.mCardLabel, { color: x.color }]}>{x.label}</Text>
                <Text style={styles.mCardValue}>{(Math.abs(x.v)/1_000_000).toFixed(2)}tr</Text>
              </View>
            ))}
          </View>

          {/* Bar chart */}
          {(mIncome > 0 || mSpent > 0) && (
            <View style={[styles.sectionCard, { marginBottom: 16 }]}>
              <Text style={styles.sectionTitle}>THU / CHI</Text>
              {[
                { label: 'Thu nhập', value: mIncome, color: COLORS.green },
                { label: 'Chi tiêu', value: mSpent,  color: COLORS.redLight },
              ].map(bar => {
                const max = Math.max(mIncome, mSpent) || 1;
                return (
                  <View key={bar.label} style={{ marginBottom: 12 }}>
                    <View style={styles.barLabelRow}>
                      <Text style={{ color: COLORS.subtext, fontSize: 12 }}>{bar.label}</Text>
                      <Text style={{ color: COLORS.text, fontSize: 12, fontWeight: '700' }}>{fmt(bar.value)}</Text>
                    </View>
                    <View style={styles.barTrack}>
                      <View style={[styles.barFill, { width: `${(bar.value/max)*100}%`, backgroundColor: bar.color }]} />
                    </View>
                  </View>
                );
              })}
              {budget && (
                <View>
                  <View style={styles.barLabelRow}>
                    <Text style={{ color: COLORS.subtext, fontSize: 12 }}>Ngân sách</Text>
                    <Text style={{ color: mSpent > budget ? COLORS.red : COLORS.accent, fontSize: 12, fontWeight: '700' }}>
                      {Math.round((mSpent/budget)*100)}%
                    </Text>
                  </View>
                  <View style={styles.barTrack}>
                    <View style={[styles.barFill, { width: `${Math.min((mSpent/budget)*100,100)}%`, backgroundColor: mSpent > budget ? COLORS.red : COLORS.accent }]} />
                  </View>
                </View>
              )}
            </View>
          )}

          {/* Category breakdown */}
          {mCatTotals.length > 0 ? (
            <View style={[styles.sectionCard, { marginBottom: 16 }]}>
              <Text style={styles.sectionTitle}>CHI TIÊU THEO DANH MỤC</Text>
              {mCatTotals.map(c => {
                const pct = mSpent ? Math.round((c.total/mSpent)*100) : 0;
                return (
                  <View key={c.id} style={{ marginBottom: 12 }}>
                    <View style={styles.barLabelRow}>
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 7 }}>
                        <Text style={{ fontSize: 15 }}>{c.icon}</Text>
                        <Text style={{ fontSize: 13, fontWeight: '500', color: COLORS.text }}>{c.label}</Text>
                      </View>
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                        <Text style={{ fontSize: 13, fontWeight: '700', color: COLORS.text }}>{fmt(c.total)}</Text>
                        <Text style={{ color: COLORS.subtext, fontSize: 11 }}>{pct}%</Text>
                      </View>
                    </View>
                    <View style={styles.barTrack}>
                      <View style={[styles.barFill, { width: `${pct}%`, backgroundColor: c.color }]} />
                    </View>
                  </View>
                );
              })}
            </View>
          ) : (
            <View style={{ alignItems: 'center', paddingVertical: 32 }}>
              <Text style={{ fontSize: 32, marginBottom: 8 }}>📭</Text>
              <Text style={{ color: COLORS.subtext, fontSize: 14 }}>Không có dữ liệu tháng này</Text>
            </View>
          )}

          {/* Transaction list */}
          {monthFeed.length > 0 && (
            <View style={styles.sectionCard}>
              <Text style={styles.sectionTitle}>GIAO DỊCH ({monthFeed.length})</Text>
              {Object.entries(feedByDate).map(([date, items]) => (
                <View key={date} style={{ marginBottom: 14 }}>
                  <Text style={styles.feedDateLabel}>{date === todayStr() ? 'Hôm nay' : fmtDate(date)}</Text>
                  {items.map(item => {
                    const isExp = item.kind === 'expense';
                    const meta  = isExp
                      ? CATEGORIES.find(c => c.id === item.category)
                      : INCOME_SOURCES.find(s => s.id === item.source);
                    return (
                      <View key={item.id} style={styles.feedRow}>
                        <View style={[styles.feedIcon, { backgroundColor: (meta?.color||'#888')+'22' }]}>
                          <Text style={{ fontSize: 16 }}>{meta?.icon||'💸'}</Text>
                        </View>
                        <View style={{ flex: 1 }}>
                          <Text style={styles.feedNote} numberOfLines={1}>{item.note}</Text>
                          <Text style={styles.feedSub}>{meta?.label}</Text>
                        </View>
                        <Text style={{ color: isExp ? COLORS.redLight : COLORS.green, fontSize: 13, fontWeight: '700' }}>
                          {isExp ? '-' : '+'}{fmtShort(item.amount)}
                        </Text>
                      </View>
                    );
                  })}
                </View>
              ))}
            </View>
          )}
        </View>
      )}

      {/* ── OVERALL TAB ── */}
      {tab === 'overall' && (
        <View>
          {catTotals.length > 0 && (
            <View style={[styles.sectionCard, { marginBottom: 16 }]}>
              <Text style={styles.sectionTitle}>CHI TIÊU THEO DANH MỤC (TẤT CẢ)</Text>
              {catTotals.map(c => {
                const pct = totalSpent ? Math.round((c.total/totalSpent)*100) : 0;
                return (
                  <View key={c.id} style={{ marginBottom: 12 }}>
                    <View style={styles.barLabelRow}>
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                        <Text style={{ fontSize: 16 }}>{c.icon}</Text>
                        <Text style={{ fontSize: 14, fontWeight: '500', color: COLORS.text }}>{c.label}</Text>
                      </View>
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                        <Text style={{ fontSize: 14, fontWeight: '700', color: COLORS.text }}>{fmt(c.total)}</Text>
                        <Text style={{ color: COLORS.subtext, fontSize: 12 }}>{pct}%</Text>
                      </View>
                    </View>
                    <View style={styles.barTrack}>
                      <View style={[styles.barFill, { width: `${pct}%`, backgroundColor: c.color }]} />
                    </View>
                  </View>
                );
              })}
            </View>
          )}

          <View style={styles.sectionCard}>
            <Text style={styles.sectionTitle}>TỔNG KẾT TOÀN BỘ</Text>
            <SummaryRow label="Tổng thu nhập"     value={fmt(totalIncome)}    color={COLORS.green} />
            <SummaryRow label="Tổng chi tiêu"     value={fmt(totalSpent)}     color={COLORS.redLight} />
            <SummaryRow label="Số dư"             value={fmt(balance)}        color={balance >= 0 ? COLORS.accent : COLORS.red} />
            {remaining != null && <SummaryRow label="Ngân sách còn lại" value={fmt(remaining)} color={remaining > 0 ? COLORS.green : COLORS.red} />}
            <SummaryRow label="Tiền gửi NH"       value={fmt(totalDeposited)} color={COLORS.purple} />
            {totalLoaned > 0 && <SummaryRow label="Cho vay chưa thu" value={fmt(totalLoaned)} color={COLORS.orange} />}
            <SummaryRow label="Số giao dịch"      value={`${txs.length + incomes.length} lần`} color={COLORS.subtext} />
          </View>
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container:    { flex: 1, backgroundColor: COLORS.bg },
  tabBar:       { flexDirection: 'row', backgroundColor: COLORS.card, borderRadius: 14, padding: 4, marginBottom: 24, gap: 4 },
  tabBtn:       { flex: 1, paddingVertical: 9, borderRadius: 10, alignItems: 'center', borderWidth: 1, borderColor: 'transparent' },
  tabBtnActive: { backgroundColor: '#2d2d4e', borderColor: 'rgba(255,255,255,0.08)' },
  tabText:      { fontSize: 13, fontWeight: '700' },
  monthNav:     { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 },
  navBtn:       { backgroundColor: COLORS.card, borderRadius: 12, width: 38, height: 38, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderColor: COLORS.border },
  monthLabel:   { color: COLORS.text, fontSize: 16, fontWeight: '800' },
  mSummary:     { flexDirection: 'row', gap: 8, marginBottom: 16 },
  mCard:        { flex: 1, borderRadius: 14, padding: 10, borderWidth: 1, alignItems: 'center' },
  mCardLabel:   { fontSize: 9, fontWeight: '700', letterSpacing: 0.5 },
  mCardValue:   { color: COLORS.text, fontSize: 13, fontWeight: '800', marginTop: 5 },
  sectionCard:  { backgroundColor: COLORS.card, borderRadius: 18, padding: 16, borderWidth: 1, borderColor: COLORS.border },
  sectionTitle: { color: COLORS.subtext, fontSize: 11, fontWeight: '700', letterSpacing: 1, marginBottom: 14 },
  barLabelRow:  { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 5 },
  barTrack:     { backgroundColor: 'rgba(255,255,255,0.06)', borderRadius: 100, height: 6 },
  barFill:      { height: 6, borderRadius: 100 },
  feedDateLabel:{ color: '#4B5563', fontSize: 11, fontWeight: '700', letterSpacing: 1, textTransform: 'uppercase', marginBottom: 8 },
  feedRow:      { flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 8 },
  feedIcon:     { width: 34, height: 34, borderRadius: 10, alignItems: 'center', justifyContent: 'center' },
  feedNote:     { fontSize: 13, fontWeight: '600', color: COLORS.text },
  feedSub:      { color: COLORS.subtext, fontSize: 11, marginTop: 1 },
});
