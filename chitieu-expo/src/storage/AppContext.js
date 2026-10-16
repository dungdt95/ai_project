import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { loadData, saveData } from './index';

const AppContext = createContext(null);

export function AppProvider({ children }) {
  const [txs,      setTxs]      = useState([]);
  const [incomes,  setIncomes]  = useState([]);
  const [deposits, setDeposits] = useState([]);
  const [loans,    setLoans]    = useState([]);
  const [budget,   setBudget]   = useState(null);
  const [loading,  setLoading]  = useState(true);

  // Load once
  useEffect(() => {
    loadData().then(d => {
      if (d) {
        setTxs(d.txs       || []);
        setIncomes(d.incomes   || []);
        setDeposits(d.deposits  || []);
        setLoans(d.loans     || []);
        setBudget(d.budget   || null);
      }
      setLoading(false);
    });
  }, []);

  // Auto-save
  useEffect(() => {
    if (loading) return;
    const t = setTimeout(() => {
      saveData({ txs, incomes, deposits, loans, budget });
    }, 400);
    return () => clearTimeout(t);
  }, [txs, incomes, deposits, loans, budget, loading]);

  // ── Actions ──────────────────────────────────────────────────────────────
  const addExpense = useCallback((item) => setTxs(p => [item, ...p]), []);
  const delExpense = useCallback((id)  => setTxs(p => p.filter(t => t.id !== id)), []);

  const addIncome  = useCallback((item) => setIncomes(p => [item, ...p]), []);
  const delIncome  = useCallback((id)   => setIncomes(p => p.filter(i => i.id !== id)), []);

  const addDeposit = useCallback((item) => setDeposits(p => [item, ...p]), []);
  const delDeposit = useCallback((id)   => setDeposits(p => p.filter(d => d.id !== id)), []);
  const editDepositAmount = useCallback((id, amount) => {
    setDeposits(p => p.map(d => d.id === id ? { ...d, amount } : d));
  }, []);

  const addLoan = useCallback((item) => setLoans(p => [item, ...p]), []);
  const delLoan = useCallback((id)   => setLoans(p => p.filter(l => l.id !== id)), []);
  const markLoanPaid = useCallback((id) => {
    setLoans(p => p.map(l => l.id === id
      ? { ...l, paid: true, paidDate: new Date().toISOString().split('T')[0] }
      : l));
  }, []);
  const partialPayLoan = useCallback((id, amount) => {
    setLoans(p => p.map(l => {
      if (l.id !== id) return l;
      const newAmount = l.amount - amount;
      const payment   = { date: new Date().toISOString().split('T')[0], amount };
      if (newAmount <= 0)
        return { ...l, paid: true, paidDate: new Date().toISOString().split('T')[0] };
      return { ...l, amount: newAmount, payments: [...(l.payments || []), payment] };
    }));
  }, []);

  return (
    <AppContext.Provider value={{
      txs, incomes, deposits, loans, budget, loading,
      setBudget,
      addExpense, delExpense,
      addIncome,  delIncome,
      addDeposit, delDeposit, editDepositAmount,
      addLoan, delLoan, markLoanPaid, partialPayLoan,
    }}>
      {children}
    </AppContext.Provider>
  );
}

export const useApp = () => useContext(AppContext);
