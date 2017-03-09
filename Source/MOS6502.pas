unit MOS6502;

interface


type
  TMOS6502 = class
    const
      // Status bits
      NEGATIVE = $80;
      OVERFLOW = $40;
      CONSTANT = $20;
      BREAK = $10;
      DECIMAL = $08;
      INTERRUPT = $04;
      ZERO = $02;
      CARRY = $01;

      // IRQ, reset, NMI vectors
      IRQVECTORH: Word = $FFFF;
      IRQVECTORL: Word = $FFFE;
      RSTVECTORH: Word = $FFFD;
      RSTVECTORL: Word = $FFFC;
      NMIVECTORH: Word = $FFFB;
      NMIVECTORL: Word = $FFFA;

    type
      TCodeExec = procedure(Src: Word) of object;
      TAddrExec = function: Word of object;

      TInstr = record
        Addr: TAddrExec;
        Code: TCodeExec;
      end;
      PInstr = ^TInstr;

      TBusWrite = procedure(Adr: Word; Value: Byte) of object;
      TBusRead = function(Adr: Word): Byte of object;

    procedure SET_NEGATIVE(const Value: Boolean); inline;
    procedure SET_OVERFLOW(const Value: Boolean); inline;
    procedure SET_CONSTANT(const Value: Boolean); inline;
    procedure SET_BREAK(const Value: Boolean); inline;
    procedure SET_DECIMAL(const Value: Boolean); inline;
    procedure SET_INTERRUPT(const Value: Boolean); inline;
    procedure SET_ZERO(const Value: Boolean); inline;
    procedure SET_CARRY(const Value: Boolean); inline;
    function IF_NEGATIVE: Boolean; inline;
    function IF_OVERFLOW: Boolean; inline;
    function IF_CONSTANT: Boolean; inline;
    function IF_BREAK: Boolean; inline;
    function IF_DECIMAL: Boolean; inline;
    function IF_INTERRUPT: Boolean; inline;
    function IF_ZERO: Boolean; inline;
    function IF_CARRY: Byte; inline;

  private
    // addressing modes
    function Addr_ACC: Word; // ACCUMULATOR
    function Addr_IMM: Word; // IMMEDIATE
    function Addr_ABS: Word; // ABSOLUTE
    function Addr_ZER: Word; // ZERO PAGE
    function Addr_ZEX: Word; // INDEXED-X ZERO PAGE
    function Addr_ZEY: Word; // INDEXED-Y ZERO PAGE
    function Addr_ABX: Word; // INDEXED-X ABSOLUTE
    function Addr_ABY: Word; // INDEXED-Y ABSOLUTE
    function Addr_IMP: Word; // IMPLIED
    function Addr_REL: Word; // RELATIVE
    function Addr_INX: Word; // INDEXED-X INDIRECT
    function Addr_INY: Word; // INDEXED-Y INDIRECT
    function Addr_ABI: Word; // ABSOLUTE INDIRECT

    // opcodes (grouped as per datasheet)
    procedure Op_ADC(Src: Word);
    procedure Op_AND(Src: Word);
    procedure Op_ASL(Src: Word);
    procedure Op_ASL_ACC(Src: Word);
    procedure Op_BCC(Src: Word);
    procedure Op_BCS(Src: Word);

    procedure Op_BEQ(Src: Word);
    procedure Op_BIT(Src: Word);
    procedure Op_BMI(Src: Word);
    procedure Op_BNE(Src: Word);
    procedure Op_BPL(Src: Word);

    procedure Op_BRK(Src: Word);
    procedure Op_BVC(Src: Word);
    procedure Op_BVS(Src: Word);
    procedure Op_CLC(Src: Word);
    procedure Op_CLD(Src: Word);

    procedure Op_CLI(Src: Word);
    procedure Op_CLV(Src: Word);
    procedure Op_CMP(Src: Word);
    procedure Op_CPX(Src: Word);
    procedure Op_CPY(Src: Word);

    procedure Op_DEC(Src: Word);
    procedure Op_DEX(Src: Word);
    procedure Op_DEY(Src: Word);
    procedure Op_EOR(Src: Word);
    procedure Op_INC(Src: Word);

    procedure Op_INX(Src: Word);
    procedure Op_INY(Src: Word);
    procedure Op_JMP(Src: Word);
    procedure Op_JSR(Src: Word);
    procedure Op_LDA(Src: Word);

    procedure Op_LDX(Src: Word);
    procedure Op_LDY(Src: Word);
    procedure Op_LSR(Src: Word);
    procedure Op_LSR_ACC(Src: Word);
    procedure Op_NOP(Src: Word);
    procedure Op_ORA(Src: Word);

    procedure Op_PHA(Src: Word);
    procedure Op_PHP(Src: Word);
    procedure Op_PLA(Src: Word);
    procedure Op_PLP(Src: Word);
    procedure Op_ROL(Src: Word);
    procedure Op_ROL_ACC(Src: Word);

    procedure Op_ROR(Src: Word);
    procedure Op_ROR_ACC(Src: Word);
    procedure Op_RTI(Src: Word);
    procedure Op_RTS(Src: Word);
    procedure Op_SBC(Src: Word);
    procedure Op_SEC(Src: Word);
    procedure Op_SED(Src: Word);

    procedure Op_SEI(Src: Word);
    procedure Op_STA(Src: Word);
    procedure Op_STX(Src: Word);
    procedure Op_STY(Src: Word);
    procedure Op_TAX(Src: Word);

    procedure Op_TAY(Src: Word);
    procedure Op_TSX(Src: Word);
    procedure Op_TXA(Src: Word);
    procedure Op_TXS(Src: Word);
    procedure Op_TYA(Src: Word);

    procedure Op_ILLEGAL(Src: Word);

    // stack operations
    procedure StackPush(const Value: Byte); inline;
    function StackPop: Byte; inline;

  protected
    // consumed clock cycles
    Cycles: Cardinal;

    InstrTable: Array [0 .. 255] of TInstr;

    // read/write callbacks
    Read: TBusRead;
    Write: TBusWrite;

    // program counter
    Pc: Word;

    // registers
    A: Byte; // accumulator
    X: Byte; // X-index
    Y: Byte; // Y-index

    // stack pointer
    Sp: Byte;

    // status register
    Status: Byte;

    IllegalOpcode: Boolean;
  public
    constructor Create(R: TBusRead; W: TBusWrite); overload; virtual;
    procedure NMI; virtual;
    procedure IRQ; virtual;
    procedure Reset; virtual;
    procedure Step; virtual;
  end;

implementation

{ TMOS6502 }

constructor TMOS6502.Create(R: TBusRead; W: TBusWrite);
var
  Instr: TInstr;
  I: Integer;
begin
  Write := W;
  Read := R;

  // fill jump table with ILLEGALs
  Instr.Addr := Addr_IMP;
  Instr.code := Op_ILLEGAL;
  for I := 0 to 256 - 1 do
    InstrTable[I] := Instr;

  // insert opcodes
  Instr.Addr := Addr_IMM;
  Instr.Code := Op_ADC;
  InstrTable[$69] := Instr;
  Instr.Addr := Addr_ABS;
  Instr.Code := Op_ADC;
  InstrTable[$6D] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_ADC;
  InstrTable[$65] := Instr;
  Instr.Addr := Addr_INX;
  Instr.Code := Op_ADC;
  InstrTable[$61] := Instr;
  Instr.Addr := Addr_INY;
  Instr.Code := Op_ADC;
  InstrTable[$71] := Instr;
  Instr.Addr := Addr_ZEX;
  Instr.Code := Op_ADC;
  InstrTable[$75] := Instr;
  Instr.Addr := Addr_ABX;
  Instr.Code := Op_ADC;
  InstrTable[$7D] := Instr;
  Instr.Addr := Addr_ABY;
  Instr.Code := Op_ADC;
  InstrTable[$79] := Instr;

  Instr.Addr := Addr_IMM;
  Instr.Code := Op_AND;
  InstrTable[$29] := Instr;
  Instr.Addr := Addr_ABS;
  Instr.Code := Op_AND;
  InstrTable[$2D] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_AND;
  InstrTable[$25] := Instr;
  Instr.Addr := Addr_INX;
  Instr.Code := Op_AND;
  InstrTable[$21] := Instr;
  Instr.Addr := Addr_INY;
  Instr.Code := Op_AND;
  InstrTable[$31] := Instr;
  Instr.Addr := Addr_ZEX;
  Instr.Code := Op_AND;
  InstrTable[$35] := Instr;
  Instr.Addr := Addr_ABX;
  Instr.Code := Op_AND;
  InstrTable[$3D] := Instr;
  Instr.Addr := Addr_ABY;
  Instr.Code := Op_AND;
  InstrTable[$39] := Instr;

  Instr.Addr := Addr_ABS;
  Instr.Code := Op_ASL;
  InstrTable[$0E] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_ASL;
  InstrTable[$06] := Instr;
  Instr.Addr := Addr_ACC;
  Instr.Code := Op_ASL_ACC;
  InstrTable[$0A] := Instr;
  Instr.Addr := Addr_ZEX;
  Instr.Code := Op_ASL;
  InstrTable[$16] := Instr;
  Instr.Addr := Addr_ABX;
  Instr.Code := Op_ASL;
  InstrTable[$1E] := Instr;

  Instr.Addr := Addr_REL;
  Instr.Code := Op_BCC;
  InstrTable[$90] := Instr;

  Instr.Addr := Addr_REL;
  Instr.Code := Op_BCS;
  InstrTable[$B0] := Instr;

  Instr.Addr := Addr_REL;
  Instr.Code := Op_BEQ;
  InstrTable[$F0] := Instr;

  Instr.Addr := Addr_ABS;
  Instr.Code := Op_BIT;
  InstrTable[$2C] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_BIT;
  InstrTable[$24] := Instr;

  Instr.Addr := Addr_REL;
  Instr.Code := Op_BMI;
  InstrTable[$30] := Instr;

  Instr.Addr := Addr_REL;
  Instr.Code := Op_BNE;
  InstrTable[$D0] := Instr;

  Instr.Addr := Addr_REL;
  Instr.Code := Op_BPL;
  InstrTable[$10] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_BRK;
  InstrTable[$00] := Instr;

  Instr.Addr := Addr_REL;
  Instr.Code := Op_BVC;
  InstrTable[$50] := Instr;

  Instr.Addr := Addr_REL;
  Instr.Code := Op_BVS;
  InstrTable[$70] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_CLC;
  InstrTable[$18] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_CLD;
  InstrTable[$D8] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_CLI;
  InstrTable[$58] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_CLV;
  InstrTable[$B8] := Instr;

  Instr.Addr := Addr_IMM;
  Instr.Code := Op_CMP;
  InstrTable[$C9] := Instr;
  Instr.Addr := Addr_ABS;
  Instr.Code := Op_CMP;
  InstrTable[$CD] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_CMP;
  InstrTable[$C5] := Instr;
  Instr.Addr := Addr_INX;
  Instr.Code := Op_CMP;
  InstrTable[$C1] := Instr;
  Instr.Addr := Addr_INY;
  Instr.Code := Op_CMP;
  InstrTable[$D1] := Instr;
  Instr.Addr := Addr_ZEX;
  Instr.Code := Op_CMP;
  InstrTable[$D5] := Instr;
  Instr.Addr := Addr_ABX;
  Instr.Code := Op_CMP;
  InstrTable[$DD] := Instr;
  Instr.Addr := Addr_ABY;
  Instr.Code := Op_CMP;
  InstrTable[$D9] := Instr;

  Instr.Addr := Addr_IMM;
  Instr.Code := Op_CPX;
  InstrTable[$E0] := Instr;
  Instr.Addr := Addr_ABS;
  Instr.Code := Op_CPX;
  InstrTable[$EC] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_CPX;
  InstrTable[$E4] := Instr;

  Instr.Addr := Addr_IMM;
  Instr.Code := Op_CPY;
  InstrTable[$C0] := Instr;
  Instr.Addr := Addr_ABS;
  Instr.Code := Op_CPY;
  InstrTable[$CC] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_CPY;
  InstrTable[$C4] := Instr;

  Instr.Addr := Addr_ABS;
  Instr.Code := Op_DEC;
  InstrTable[$CE] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_DEC;
  InstrTable[$C6] := Instr;
  Instr.Addr := Addr_ZEX;
  Instr.Code := Op_DEC;
  InstrTable[$D6] := Instr;
  Instr.Addr := Addr_ABX;
  Instr.Code := Op_DEC;
  InstrTable[$DE] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_DEX;
  InstrTable[$CA] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_DEY;
  InstrTable[$88] := Instr;

  Instr.Addr := Addr_IMM;
  Instr.Code := Op_EOR;
  InstrTable[$49] := Instr;
  Instr.Addr := Addr_ABS;
  Instr.Code := Op_EOR;
  InstrTable[$4D] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_EOR;
  InstrTable[$45] := Instr;
  Instr.Addr := Addr_INX;
  Instr.Code := Op_EOR;
  InstrTable[$41] := Instr;
  Instr.Addr := Addr_INY;
  Instr.Code := Op_EOR;
  InstrTable[$51] := Instr;
  Instr.Addr := Addr_ZEX;
  Instr.Code := Op_EOR;
  InstrTable[$55] := Instr;
  Instr.Addr := Addr_ABX;
  Instr.Code := Op_EOR;
  InstrTable[$5D] := Instr;
  Instr.Addr := Addr_ABY;
  Instr.Code := Op_EOR;
  InstrTable[$59] := Instr;

  Instr.Addr := Addr_ABS;
  Instr.Code := Op_INC;
  InstrTable[$EE] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_INC;
  InstrTable[$E6] := Instr;
  Instr.Addr := Addr_ZEX;
  Instr.Code := Op_INC;
  InstrTable[$F6] := Instr;
  Instr.Addr := Addr_ABX;
  Instr.Code := Op_INC;
  InstrTable[$FE] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_INX;
  InstrTable[$E8] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_INY;
  InstrTable[$C8] := Instr;

  Instr.Addr := Addr_ABS;
  Instr.Code := Op_JMP;
  InstrTable[$4C] := Instr;
  Instr.Addr := Addr_ABI;
  Instr.Code := Op_JMP;
  InstrTable[$6C] := Instr;

  Instr.Addr := Addr_ABS;
  Instr.Code := Op_JSR;
  InstrTable[$20] := Instr;

  Instr.Addr := Addr_IMM;
  Instr.Code := Op_LDA;
  InstrTable[$A9] := Instr;
  Instr.Addr := Addr_ABS;
  Instr.Code := Op_LDA;
  InstrTable[$AD] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_LDA;
  InstrTable[$A5] := Instr;
  Instr.Addr := Addr_INX;
  Instr.Code := Op_LDA;
  InstrTable[$A1] := Instr;
  Instr.Addr := Addr_INY;
  Instr.Code := Op_LDA;
  InstrTable[$B1] := Instr;
  Instr.Addr := Addr_ZEX;
  Instr.Code := Op_LDA;
  InstrTable[$B5] := Instr;
  Instr.Addr := Addr_ABX;
  Instr.Code := Op_LDA;
  InstrTable[$BD] := Instr;
  Instr.Addr := Addr_ABY;
  Instr.Code := Op_LDA;
  InstrTable[$B9] := Instr;

  Instr.Addr := Addr_IMM;
  Instr.Code := Op_LDX;
  InstrTable[$A2] := Instr;
  Instr.Addr := Addr_ABS;
  Instr.Code := Op_LDX;
  InstrTable[$AE] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_LDX;
  InstrTable[$A6] := Instr;
  Instr.Addr := Addr_ABY;
  Instr.Code := Op_LDX;
  InstrTable[$BE] := Instr;
  Instr.Addr := Addr_ZEY;
  Instr.Code := Op_LDX;
  InstrTable[$B6] := Instr;

  Instr.Addr := Addr_IMM;
  Instr.Code := Op_LDY;
  InstrTable[$A0] := Instr;
  Instr.Addr := Addr_ABS;
  Instr.Code := Op_LDY;
  InstrTable[$AC] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_LDY;
  InstrTable[$A4] := Instr;
  Instr.Addr := Addr_ZEX;
  Instr.Code := Op_LDY;
  InstrTable[$B4] := Instr;
  Instr.Addr := Addr_ABX;
  Instr.Code := Op_LDY;
  InstrTable[$BC] := Instr;

  Instr.Addr := Addr_ABS;
  Instr.Code := Op_LSR;
  InstrTable[$4E] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_LSR;
  InstrTable[$46] := Instr;
  Instr.Addr := Addr_ACC;
  Instr.Code := Op_LSR_ACC;
  InstrTable[$4A] := Instr;
  Instr.Addr := Addr_ZEX;
  Instr.Code := Op_LSR;
  InstrTable[$56] := Instr;
  Instr.Addr := Addr_ABX;
  Instr.Code := Op_LSR;
  InstrTable[$5E] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_NOP;
  InstrTable[$EA] := Instr;

  Instr.Addr := Addr_IMM;
  Instr.Code := Op_ORA;
  InstrTable[$09] := Instr;
  Instr.Addr := Addr_ABS;
  Instr.Code := Op_ORA;
  InstrTable[$0D] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_ORA;
  InstrTable[$05] := Instr;
  Instr.Addr := Addr_INX;
  Instr.Code := Op_ORA;
  InstrTable[$01] := Instr;
  Instr.Addr := Addr_INY;
  Instr.Code := Op_ORA;
  InstrTable[$11] := Instr;
  Instr.Addr := Addr_ZEX;
  Instr.Code := Op_ORA;
  InstrTable[$15] := Instr;
  Instr.Addr := Addr_ABX;
  Instr.Code := Op_ORA;
  InstrTable[$1D] := Instr;
  Instr.Addr := Addr_ABY;
  Instr.Code := Op_ORA;
  InstrTable[$19] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_PHA;
  InstrTable[$48] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_PHP;
  InstrTable[$08] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_PLA;
  InstrTable[$68] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_PLP;
  InstrTable[$28] := Instr;

  Instr.Addr := Addr_ABS;
  Instr.Code := Op_ROL;
  InstrTable[$2E] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_ROL;
  InstrTable[$26] := Instr;
  Instr.Addr := Addr_ACC;
  Instr.Code := Op_ROL_ACC;
  InstrTable[$2A] := Instr;
  Instr.Addr := Addr_ZEX;
  Instr.Code := Op_ROL;
  InstrTable[$36] := Instr;
  Instr.Addr := Addr_ABX;
  Instr.Code := Op_ROL;
  InstrTable[$3E] := Instr;

  Instr.Addr := Addr_ABS;
  Instr.Code := Op_ROR;
  InstrTable[$6E] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_ROR;
  InstrTable[$66] := Instr;
  Instr.Addr := Addr_ACC;
  Instr.Code := Op_ROR_ACC;
  InstrTable[$6A] := Instr;
  Instr.Addr := Addr_ZEX;
  Instr.Code := Op_ROR;
  InstrTable[$76] := Instr;
  Instr.Addr := Addr_ABX;
  Instr.Code := Op_ROR;
  InstrTable[$7E] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_RTI;
  InstrTable[$40] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_RTS;
  InstrTable[$60] := Instr;

  Instr.Addr := Addr_IMM;
  Instr.Code := Op_SBC;
  InstrTable[$E9] := Instr;
  Instr.Addr := Addr_ABS;
  Instr.Code := Op_SBC;
  InstrTable[$ED] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_SBC;
  InstrTable[$E5] := Instr;
  Instr.Addr := Addr_INX;
  Instr.Code := Op_SBC;
  InstrTable[$E1] := Instr;
  Instr.Addr := Addr_INY;
  Instr.Code := Op_SBC;
  InstrTable[$F1] := Instr;
  Instr.Addr := Addr_ZEX;
  Instr.Code := Op_SBC;
  InstrTable[$F5] := Instr;
  Instr.Addr := Addr_ABX;
  Instr.Code := Op_SBC;
  InstrTable[$FD] := Instr;
  Instr.Addr := Addr_ABY;
  Instr.Code := Op_SBC;
  InstrTable[$F9] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_SEC;
  InstrTable[$38] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_SED;
  InstrTable[$F8] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_SEI;
  InstrTable[$78] := Instr;

  Instr.Addr := Addr_ABS;
  Instr.Code := Op_STA;
  InstrTable[$8D] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_STA;
  InstrTable[$85] := Instr;
  Instr.Addr := Addr_INX;
  Instr.Code := Op_STA;
  InstrTable[$81] := Instr;
  Instr.Addr := Addr_INY;
  Instr.Code := Op_STA;
  InstrTable[$91] := Instr;
  Instr.Addr := Addr_ZEX;
  Instr.Code := Op_STA;
  InstrTable[$95] := Instr;
  Instr.Addr := Addr_ABX;
  Instr.Code := Op_STA;
  InstrTable[$9D] := Instr;
  Instr.Addr := Addr_ABY;
  Instr.Code := Op_STA;
  InstrTable[$99] := Instr;

  Instr.Addr := Addr_ABS;
  Instr.Code := Op_STX;
  InstrTable[$8E] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_STX;
  InstrTable[$86] := Instr;
  Instr.Addr := Addr_ZEY;
  Instr.Code := Op_STX;
  InstrTable[$96] := Instr;

  Instr.Addr := Addr_ABS;
  Instr.Code := Op_STY;
  InstrTable[$8C] := Instr;
  Instr.Addr := Addr_ZER;
  Instr.Code := Op_STY;
  InstrTable[$84] := Instr;
  Instr.Addr := Addr_ZEX;
  Instr.Code := Op_STY;
  InstrTable[$94] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_TAX;
  InstrTable[$AA] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_TAY;
  InstrTable[$A8] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_TSX;
  InstrTable[$BA] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_TXA;
  InstrTable[$8A] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_TXS;
  InstrTable[$9A] := Instr;

  Instr.Addr := Addr_IMP;
  Instr.Code := Op_TYA;
  InstrTable[$98] := Instr;
end;

procedure TMOS6502.SET_NEGATIVE(const Value: Boolean);
begin
  if Value then
    Status := Status or NEGATIVE
  else
    Status := Status and (not NEGATIVE);
end;

procedure TMOS6502.SET_OVERFLOW(const Value: Boolean);
begin
  if Value then
    Status := Status or OVERFLOW
  else
    Status := Status and (not OVERFLOW);
end;

procedure TMOS6502.SET_CONSTANT(const Value: Boolean);
begin
  if Value then
    Status := Status or CONSTANT
  else
    Status := Status and (not CONSTANT);
end;

procedure TMOS6502.SET_BREAK(const Value: Boolean);
begin
  if Value then
    Status := Status or BREAK
  else
    Status := Status and (not BREAK);
end;

procedure TMOS6502.SET_DECIMAL(const Value: Boolean);
begin
  if Value then
    Status := Status or DECIMAL
  else
    Status := Status and (not DECIMAL);
end;

procedure TMOS6502.SET_INTERRUPT(const Value: Boolean);
begin
  if Value then
    Status := Status or INTERRUPT
  else
    Status := Status and (not INTERRUPT);
end;

procedure TMOS6502.SET_ZERO(const Value: Boolean);
begin
  if Value then
    Status := Status or ZERO
  else
    Status := Status and (not ZERO);
end;

procedure TMOS6502.SET_CARRY(const Value: Boolean);
begin
  if Value then
    Status := Status or CARRY
  else
    Status := Status and (not CARRY);
end;


function TMOS6502.IF_NEGATIVE: Boolean;
begin
  Result := ((Status and NEGATIVE) <> 0);
end;

function TMOS6502.IF_OVERFLOW: Boolean;
begin
  Result := ((Status and OVERFLOW) <> 0);
end;

function TMOS6502.IF_CONSTANT: Boolean;
begin
  Result := ((Status and CONSTANT) <> 0);
end;

function TMOS6502.IF_BREAK: Boolean;
begin
  Result := ((Status and BREAK) <> 0);
end;

function TMOS6502.IF_DECIMAL: Boolean;
begin
  Result := ((Status and DECIMAL) <> 0);
end;

function TMOS6502.IF_INTERRUPT: Boolean;
begin
  Result := ((Status and INTERRUPT) <> 0);
end;

function TMOS6502.IF_ZERO: Boolean;
begin
  Result := ((Status and ZERO) <> 0);
end;

function TMOS6502.IF_CARRY: Byte;
begin
  if (Status and CARRY) <> 0 then
    Result := 1
  else
    Result := 0;
end;

function TMOS6502.Addr_ACC: Word;
begin
  Result := 0; // not used
end;

function TMOS6502.Addr_IMM: Word;
begin
  Result := Pc;
  Inc(Pc);
end;

function TMOS6502.Addr_ABS: Word;
var
  AddrL, AddrH, Addr: Word;
begin
  AddrL := Read(Pc);
  Inc(Pc);
  AddrH := Read(Pc);
  Inc(Pc);

  Addr := AddrL + (AddrH shl 8);

  Result := Addr;
end;

function TMOS6502.Addr_ZER: Word;
begin
  Result := Read(Pc);
  Inc(Pc);
end;

function TMOS6502.Addr_IMP: Word;
begin
  Result := 0; // not used
end;

function TMOS6502.Addr_REL: Word;
var
  Offset, Addr: Word;
begin
  Offset := Read(Pc);
  Inc(Pc);
  if (Offset and $80) <> 0 then
    Offset := Offset or $FF00;

  Addr := Pc + Offset;
  Result := Addr;
end;

function TMOS6502.Addr_ABI: Word;
var
  AddrL, AddrH, EffL, EffH, Abs, Addr: Word;
begin
  AddrL := Read(Pc);
  Inc(Pc);
  AddrH := Read(Pc);
  Inc(Pc);

  Abs := (AddrH shl 8) or AddrL;
  EffL := Read(Abs);
  EffH := Read((Abs and $FF00) + ((Abs + 1) and $00FF));

  Addr := EffL + $100 * EffH;
  Result := Addr;
end;

function TMOS6502.Addr_ZEX: Word;
var
  Addr: Word;
begin
  Addr := (Read(Pc) + X) mod 256;
  Inc(Pc);
  Result := Addr;
end;

function TMOS6502.Addr_ZEY: Word;
var
  Addr: Word;
begin
  Addr := (Read(Pc) + Y) mod 256;
  Inc(Pc);
  Result := Addr;
end;

function TMOS6502.Addr_ABX: Word;
var
  AddrL: Word;
  AddrH: Word;
  Addr: Word;
begin
  AddrL := Read(Pc);
  Inc(Pc);
  AddrH := Read(Pc);
  Inc(Pc);

  Addr := AddrL + (AddrH shl 8) + X;
  Result := Addr;
end;

function TMOS6502.Addr_ABY: Word;
var
  AddrL: Word;
  AddrH: Word;
  Addr: Word;
begin
  AddrL := Read(Pc);
  Inc(Pc);
  AddrH := Read(Pc);
  Inc(Pc);

  Addr := AddrL + (AddrH shl 8) + Y;
  Result := Addr;
end;

function TMOS6502.Addr_INX: Word;
var
  ZeroL, ZeroH: Word;
  Addr: Word;
begin
  ZeroL := (Read(Pc) + X) mod 256;
  Inc(Pc);
  ZeroH := (ZeroL + 1) mod 256;
  Addr := Read(ZeroL) + (Read(ZeroH) shl 8);
  Result := Addr;
end;

function TMOS6502.Addr_INY: Word;
var
  ZeroL, ZeroH: Word;
  Addr: Word;
begin
  ZeroL := Read(Pc);
  Inc(Pc);

  ZeroH := (ZeroL + 1) mod 256;
  Addr := Read(ZeroL) + (Read(ZeroH) shl 8) + Y;
  Result := Addr;
end;

procedure TMOS6502.Reset;
begin
  A := $aa;
  X := $00;
  Y := $00;

  Status := BREAK or INTERRUPT OR ZERO or CONSTANT;
  Sp := $FD;

  Pc := (Read(RSTVECTORH) shl 8) + Read(RSTVECTORL); // load PC from reset vector

  Cycles := 6; // according to the datasheet, the reset routine takes 6 clock cycles
  IllegalOpcode := false;
end;

procedure TMOS6502.StackPush(const Value: Byte);
begin
  Write($0100 + Sp, Value);
  if Sp = $00 then
    Sp := $FF
  else
    Dec(Sp);
end;

function TMOS6502.StackPop: Byte;
begin
  if Sp = $FF then
    Sp := $00
  else
    Inc(Sp);

  Result := Read($0100 + Sp);
end;

procedure TMOS6502.IRQ;
begin
  if (not IF_INTERRUPT) then
  begin
    SET_BREAK(False);
    StackPush((Pc shr 8) and $FF);
    StackPush(Pc and $FF);
    StackPush(Status);
    SET_INTERRUPT(True);
    Pc := (Read(IRQVECTORH) shl 8) + Read(IRQVECTORL);
  end;
end;

procedure TMOS6502.NMI;
begin
  SET_BREAK(false);
  StackPush((Pc shr 8) and $FF);
  StackPush(Pc and $FF);
  StackPush(Status);
  SET_INTERRUPT(True);
  Pc := (Read(NMIVECTORH) shl 8) + Read(NMIVECTORL);
end;

procedure TMOS6502.Step;
var
  Opcode: Byte;
  Instr: PInstr;
  Src: Word;
begin
  // fetch
  Opcode := Read(Pc);
  Inc(Pc);

  // decode and execute
  Instr := @InstrTable[Opcode];
  Src := Instr.Addr;
  Instr.Code(Src);

  Inc(Cycles);
end;

procedure TMOS6502.Op_ILLEGAL(Src: Word);
begin
  IllegalOpcode := true;
end;

procedure TMOS6502.Op_AND(Src: Word);
var
  M: Byte;
  Res: Byte;
begin
  M := Read(Src);
  Res := M and A;
  SET_NEGATIVE((Res and $80) <> 0);
  SET_ZERO(Res = 0);
  A := Res;
end;

procedure TMOS6502.Op_ASL(Src: Word);
var
  M: Byte;
begin
  M := Read(Src);
  SET_CARRY((M and $80) <> 0);
  M := M shl 1;
  M := M and $FF;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  Write(Src, M);
end;

procedure TMOS6502.Op_ASL_ACC(Src: Word);
var
  M: Byte;
begin
  M := A;
  SET_CARRY((M and $80) <> 0);
  M := M shl 1;
  M := M and $FF;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  A := M;
end;

procedure TMOS6502.Op_BCC(Src: Word);
begin
  if IF_CARRY = 0 then
    Pc := Src;
end;

procedure TMOS6502.Op_BCS(Src: Word);
begin
  if IF_CARRY = 1 then
    Pc := Src;
end;

procedure TMOS6502.Op_BEQ(Src: Word);
begin
  if IF_ZERO then
    Pc := Src;
end;

procedure TMOS6502.Op_BIT(Src: Word);
var
  M: Byte;
  Res: Byte;
begin
  M := Read(Src);
  Res := M and A;
  SET_NEGATIVE((Res and $80) <> 0);
  Status := (Status and $3F) or (M and $C0);
  SET_ZERO(Res = 0);
end;

procedure TMOS6502.Op_BMI(Src: Word);
begin
  if IF_NEGATIVE then
    Pc := Src;
end;

procedure TMOS6502.Op_BNE(Src: Word);
begin
  if not (IF_ZERO) then
    Pc := Src;
end;

procedure TMOS6502.Op_BPL(Src: Word);
begin
  if not (IF_NEGATIVE) then
    Pc := Src;
end;

procedure TMOS6502.Op_BRK(Src: Word);
begin
  Inc(Pc);
  StackPush((Pc shr 8) and $FF);
  StackPush(Pc and $FF);
  StackPush(Status or BREAK);
  SET_INTERRUPT(True);
  Pc := (Read(IRQVECTORH) shl 8) + Read(IRQVECTORL);
end;

procedure TMOS6502.Op_BVC(Src: Word);
begin
  if not (IF_OVERFLOW) then
    Pc := Src;
end;

procedure TMOS6502.Op_BVS(Src: Word);
begin
  if IF_OVERFLOW then
    Pc := Src;
end;

procedure TMOS6502.Op_CLC(Src: Word);
begin
  SET_CARRY(False);
end;

procedure TMOS6502.Op_CLD(Src: Word);
begin
  SET_DECIMAL(False);
end;

procedure TMOS6502.Op_CLI(Src: Word);
begin
  SET_INTERRUPT(False);
end;

procedure TMOS6502.Op_CLV(Src: Word);
begin
  SET_OVERFLOW(False);
end;

procedure TMOS6502.Op_CMP(Src: Word);
var
  Tmp: Cardinal;
begin
  Tmp := A - Read(Src);
  SET_CARRY(Tmp < $100);
  SET_NEGATIVE((Tmp and $80) <> 0);
  SET_ZERO((Tmp and $FF)=0);
end;

procedure TMOS6502.Op_CPX(Src: Word);
var
  Tmp: Cardinal;
begin
  Tmp := X - Read(Src);
  SET_CARRY(Tmp < $100);
  SET_NEGATIVE((Tmp and $80) <> 0);
  SET_ZERO((Tmp and $FF)=0);
end;

procedure TMOS6502.Op_CPY(Src: Word);
var
  Tmp: Cardinal;
begin
  Tmp := Y - Read(Src);
  SET_CARRY(Tmp < $100);
  SET_NEGATIVE((Tmp and $80) <> 0);
  SET_ZERO((Tmp and $FF)=0);
end;

procedure TMOS6502.Op_DEC(Src: Word);
var
  M: Byte;
begin
  M := Read(Src);
  M := M - 1;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  Write(Src, M);
end;

procedure TMOS6502.Op_DEX(Src: Word);
var
  M: Byte;
begin
  M := X;
  M := M - 1;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  X := M;
end;

procedure TMOS6502.Op_DEY(Src: Word);
var
  M: Byte;
begin
  M := Y;
  M := M - 1;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  Y := M;
end;

procedure TMOS6502.Op_EOR(Src: Word);
var
  M: Byte;
begin
  M := Read(Src);
  M := A xor M;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  A := M;
end;

procedure TMOS6502.Op_INC(Src: Word);
var
  M: Byte;
begin
  M := Read(Src);
  M := M + 1;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  Write(Src, M);
end;

procedure TMOS6502.Op_INX(Src: Word);
var
  M: Byte;
begin
  M := X;
  M := M + 1;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  X := M;
end;

procedure TMOS6502.Op_INY(Src: Word);
var
  M: Byte;
begin
  M := Y;
  M := M + 1;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  Y := M;
end;

procedure TMOS6502.Op_JMP(Src: Word);
begin
  Pc := Src;
end;

procedure TMOS6502.Op_JSR(Src: Word);
begin
  Dec(Pc);
  StackPush((Pc shr 8) and $FF);
  StackPush(Pc and $FF);
  Pc := Src;
end;

procedure TMOS6502.Op_LDA(Src: Word);
var
  M: Byte;
begin
  M := Read(Src);
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  A := M;
end;

procedure TMOS6502.Op_LDX(Src: Word);
var
  M: Byte;
begin
  M := Read(Src);
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  X := M;
end;

procedure TMOS6502.Op_LDY(Src: Word);
var
  M: Byte;
begin
  M := Read(Src);
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  Y := M;
end;

procedure TMOS6502.Op_LSR(Src: Word);
var
  M: Byte;
begin
  M := Read(Src);
  SET_CARRY((M and $01) <> 0);
  M := M shr 1;
  SET_NEGATIVE(False);
  SET_ZERO(M = 0);
  Write(Src, M);
end;

procedure TMOS6502.Op_LSR_ACC(Src: Word);
var
  M: Byte;
begin
  M := A;
  SET_CARRY((M and $01) <> 0);
  M := M shr 1;
  SET_NEGATIVE(False);
  SET_ZERO(M = 0);
  A := M;
end;

procedure TMOS6502.Op_NOP(Src: Word);
begin
  // no operation
end;

procedure TMOS6502.Op_ORA(Src: Word);
var
  M: Byte;
begin
  M := Read(Src);
  M := A or M;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  A := M;
end;

procedure TMOS6502.Op_PHA(Src: Word);
begin
  StackPush(A);
end;

procedure TMOS6502.Op_PHP(Src: Word);
begin
  StackPush(Status or BREAK);
end;

procedure TMOS6502.Op_PLA(Src: Word);
begin
  A := StackPop;
  SET_NEGATIVE((A and $80) <> 0);
  SET_ZERO(A = 0);
end;

procedure TMOS6502.Op_PLP(Src: Word);
begin
  Status := StackPop;
  SET_CONSTANT(True);
end;

procedure TMOS6502.Op_ROL(Src: Word);
var
  M: Word;
begin
  M := Read(Src);
  M := M shl 1;
  if IF_CARRY = 1 then
    M := M or $01;
  SET_CARRY(M > $FF);
  M := M and $FF;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  Write(Src, M);
end;

procedure TMOS6502.Op_ROL_ACC(Src: Word);
var
  M: Word;
begin
  M := A;
  M := M shl 1;
  if IF_CARRY = 1 then
    M := M or $01;
  SET_CARRY(M > $FF);
  M := M and $FF;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  A := M;
end;

procedure TMOS6502.Op_ROR(Src: Word);
var
  M: Word;
begin
  M := Read(Src);
  if IF_CARRY = 1 then
    M := M or $100;
  SET_CARRY((M and $01) <> 0);
  M := M shr 1;
  M := M and $FF;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  Write(Src, M);
end;

procedure TMOS6502.Op_ROR_ACC(Src: Word);
var
  M: Word;
begin
  M := A;
  if IF_CARRY = 1 then
    M := M or $100;
    SET_CARRY((M and $01) <> 0);
  M := M shr 1;
  M := M and $FF;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  A := M;
end;

procedure TMOS6502.Op_RTI(Src: Word);
var
  Lo, Hi: Byte;
begin
  Status := StackPop;

  Lo := StackPop;
  Hi := StackPop;

  Pc := (Hi shl 8) or Lo;
end;

procedure TMOS6502.Op_RTS(Src: Word);
var
  Lo, Hi: Byte;
begin
  Lo := StackPop;
  Hi := StackPop;

  Pc := (Hi shl 8) or Lo + 1;
end;

procedure TMOS6502.Op_ADC(Src: Word);
var
  M: Byte;
  Tmp: Cardinal;
begin
  M := Read(Src);
  Tmp := M + A + IF_CARRY;

  SET_ZERO((Tmp and $FF)=0);

  if IF_DECIMAL then
  begin
    if (((A and $F) + (M and $F) + IF_CARRY) > 9) then
      Tmp := Tmp + 6;

    SET_NEGATIVE((Tmp and $80) <> 0);

    SET_OVERFLOW( (((A xor M) and $80) = 0) and (((A xor Tmp) and $80) <> 0));

    if Tmp > $99 then
      Tmp := Tmp + $60;

    SET_CARRY(Tmp > $99);
  end
  else
  begin
    SET_NEGATIVE((Tmp and $80) <> 0);
    SET_OVERFLOW( (((A xor M) and $80)=0) and (((A xor Tmp) and $80) <> 0));
    SET_CARRY(Tmp > $FF);
  end;

  A := Tmp and $FF;
end;


procedure TMOS6502.Op_SBC(Src: Word);
var
  M: Byte;
  Tmp: Word;
begin
  M := Read(Src);
  Tmp := A - M - (1-IF_CARRY);

  SET_NEGATIVE((Tmp and $80) <> 0);

  SET_ZERO((Tmp and $FF) = 0);

   SET_OVERFLOW( (((A xor Tmp) and $80) <> 0)  and (((A xor M) and $80) <> 0));

  if IF_DECIMAL then
  begin
    if (((A and $0F) - (1-IF_CARRY)) < (M and $0F)) then
      Tmp := Tmp - 6;

    if Tmp > $99 then
      Tmp := Tmp - $60;
  end;

  SET_CARRY(Tmp < $100);
  A := (Tmp and $FF);
end;

procedure TMOS6502.Op_SEC(Src: Word);
begin
  SET_CARRY(True);
end;

procedure TMOS6502.Op_SED(Src: Word);
begin
  SET_DECIMAL(True);
end;

procedure TMOS6502.Op_SEI(Src: Word);
begin
  SET_INTERRUPT(True);
end;

procedure TMOS6502.Op_STA(Src: Word);
begin
  Write(Src, A);
end;

procedure TMOS6502.Op_STX(Src: Word);
begin
  Write(Src, X);
end;

procedure TMOS6502.Op_STY(Src: Word);
begin
  Write(Src, Y);
end;

procedure TMOS6502.Op_TAX(Src: Word);
var
  M: Byte;
begin
  M := A;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  X := M;
end;

procedure TMOS6502.Op_TAY(Src: Word);
var
  M: Byte;
begin
  M := A;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  Y := M;
end;

procedure TMOS6502.Op_TSX(Src: Word);
var
  M: Byte;
begin
  M := Sp;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  x := M;
end;

procedure TMOS6502.Op_TXA(Src: Word);
var
  M: Byte;
begin
  M := X;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  A := M;
end;

procedure TMOS6502.Op_TXS(Src: Word);
begin
  Sp := X;
end;

procedure TMOS6502.Op_TYA(Src: Word);
var
  M: Byte;
begin
  M := Y;
  SET_NEGATIVE((M and $80) <> 0);
  SET_ZERO(M = 0);
  A := M;
end;

end.
