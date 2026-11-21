import React, { useState } from 'react';
import { ExcelProvider } from './context/ExcelContext';
import { TitleBar } from './components/TitleBar';
import { Ribbon } from './components/Ribbon';
import { FormulaBar } from './components/FormulaBar';
import { Grid } from './components/Grid';
import { SheetTabs } from './components/SheetTabs';
import { StatusBar } from './components/StatusBar';
import { FunctionDialog } from './components/FunctionDialog';

const MainApp: React.FC = () => {
  const [isFunctionDialogOpen, setIsFunctionDialogOpen] = useState(false);

  return (
    <div className="excel-app-container">
      {/* Title Bar (Quick Access & Window Controls) */}
      <TitleBar />

      {/* Office 365 Ribbon Bar */}
      <Ribbon onOpenFunctionDialog={() => setIsFunctionDialogOpen(true)} />

      {/* Formula Bar */}
      <FormulaBar onOpenFunctionDialog={() => setIsFunctionDialogOpen(true)} />

      {/* Main Grid Spreadsheet */}
      <Grid />

      {/* Bottom Sheet Tabs */}
      <SheetTabs />

      {/* Bottom Status Bar */}
      <StatusBar />

      {/* Function Dialog */}
      <FunctionDialog
        isOpen={isFunctionDialogOpen}
        onClose={() => setIsFunctionDialogOpen(false)}
      />
    </div>
  );
};

export const App: React.FC = () => {
  return (
    <ExcelProvider>
      <MainApp />
    </ExcelProvider>
  );
};

export default App;
