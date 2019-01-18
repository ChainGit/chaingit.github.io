function wave=ReadLeCroyBinaryWaveform(fn)

%打开TRC文件
fid=fopen(fn,'r');
if fid==-1 
   fprintf(sprintf('ERROR: file not found: %s', fn));
   return
end;

%获取WAVEDESC数据
data=fread(fid,50);
WAVEDESC=strfind(char(data(1:50)'),'WAVEDESC')-1; 
   
%波形WAVEDESC的模板
aTEMPLATE_NAME		= WAVEDESC+ 16;
aCOMM_TYPE			= WAVEDESC+ 32;
aCOMM_ORDER			= WAVEDESC+ 34;
aWAVE_DESCRIPTOR	= WAVEDESC+ 36;
aUSER_TEXT			= WAVEDESC+ 40;
aTRIGTIME_ARRAY     = WAVEDESC+ 48;
aWAVE_ARRAY_1		= WAVEDESC+ 60;
aINSTRUMENT_NAME	= WAVEDESC+ 76;
aINSTRUMENT_NUMBER  = WAVEDESC+ 92;
aTRACE_LABEL		= WAVEDESC+ 96;
aWAVE_ARRAY_COUNT	= WAVEDESC+ 116;
aVERTICAL_GAIN		= WAVEDESC+ 156;
aVERTICAL_OFFSET	= WAVEDESC+ 160;
aNOMINAL_BITS		= WAVEDESC+ 172;
aHORIZ_INTERVAL     = WAVEDESC+ 176;
aHORIZ_OFFSET		= WAVEDESC+ 180;
aVERTUNIT			= WAVEDESC+ 196;
aHORUNIT			= WAVEDESC+ 244;
aTRIGGER_TIME		= WAVEDESC+ 296;
aRECORD_TYPE		= WAVEDESC+ 316;
aPROCESSING_DONE	= WAVEDESC+ 318;
aTIMEBASE			= WAVEDESC+ 324;
aVERT_COUPLING		= WAVEDESC+ 326;
aPROBE_ATT			= WAVEDESC+ 328;
aFIXED_VERT_GAIN	= WAVEDESC+ 332;
aBANDWIDTH_LIMIT	= WAVEDESC+ 334;
aVERTICAL_VERNIER	= WAVEDESC+ 336;
aACQ_VERT_OFFSET	= WAVEDESC+ 340;
aWAVE_SOURCE		= WAVEDESC+ 344;

%判断数据的大小端存储方式
fseek(fid,aCOMM_ORDER,'bof');
COMM_ORDER=fread(fid,1,'int16');

fclose(fid);

if COMM_ORDER==0    
   fid=fopen(fn,'r','ieee-be');		% HIFIRST
else 
   fid=fopen(fn,'r','ieee-le');		% LOFIRST
end;

%针对WAVEDESC的文本翻译出对应的实际内容
wave.info.INSTRUMENT_NAME	= ReadString(fid, aINSTRUMENT_NAME);
wave.info.INSTRUMENT_NUMBER	= ReadLong	(fid, aINSTRUMENT_NUMBER);
wave.info.Filename			= fn;

wave.info.TRIGGER_TIME		= ReadTimestamp(fid, aTRIGGER_TIME);

tmp=['channel 1';'channel 2';'channel 3';'channel 4';'unknown  '];
wave.info.WAVE_SOURCE			= tmp (1+ ReadWord(fid, aWAVE_SOURCE),:);

tmp=['DC_50_Ohms'; 'ground    ';'DC 1MOhm  ';'ground    ';'AC 1MOhm  '];
wave.info.VERT_COUPLING		= deblank (tmp (1+ ReadWord(fid, aVERT_COUPLING),:));

tmp=['off'; 'on '];
wave.info.BANDWIDTH_LIMIT	= deblank (tmp (1+ ReadWord(fid, aBANDWIDTH_LIMIT),:));

tmp=[
   'single_sweep      ';	'interleaved       '; 'histogram         ';
   'graph             ';	'filter_coefficient'; 'complex           ';
   'extrema           ';	'sequence_obsolete '; 'centered_RIS      ';	
   'peak_detect       '];
wave.info.RECORD_TYPE		= deblank (tmp (1+ ReadWord(fid, aRECORD_TYPE),:));

tmp=[
   'no_processing';   'fir_filter   '; 'interpolated ';   'sparsed      ';
   'autoscaled   ';   'no_result    '; 'rolling      ';   'cumulative   '];
wave.info.PROCESSING_DONE		= deblank (tmp (1+ ReadWord(fid, aPROCESSING_DONE),:));

FIXED_VERT_GAIN			= ReadFixed_vert_gain(fid, aFIXED_VERT_GAIN);
PROBE_ATT				= ReadFloat (fid, aPROBE_ATT);
VERTICAL_GAIN			= ReadFloat	(fid, aVERTICAL_GAIN);
VERTICAL_OFFSET			= ReadFloat	(fid, aVERTICAL_OFFSET);
wave.info.NOMINAL_BITS	= ReadWord	(fid, aNOMINAL_BITS);
wave.info.Gain_with_Probe = strcat (Float_to_Eng(FIXED_VERT_GAIN*PROBE_ATT), 'V/div');

HORIZ_INTERVAL			= ReadFloat(fid, aHORIZ_INTERVAL);
HORIZ_OFFSET			= ReadDouble(fid, aHORIZ_OFFSET);
wave.info.TIMEBASE	= strcat (Float_to_Eng (ReadTimebase(fid,aTIMEBASE)), 's/div');
wave.info.SampleRate	= strcat (Float_to_Eng(1/HORIZ_INTERVAL) , 'S/sec');
wave.desc.Ts			= HORIZ_INTERVAL;
wave.desc.fs			= 1/HORIZ_INTERVAL;

COMM_TYPE			= ReadWord(fid, aCOMM_TYPE);
WAVE_DESCRIPTOR 	= ReadLong(fid, aWAVE_DESCRIPTOR);
USER_TEXT			= ReadLong(fid, aUSER_TEXT);
WAVE_ARRAY_1		= ReadLong(fid, aWAVE_ARRAY_1);
WAVE_ARRAY_COUNT    = ReadLong(fid, aWAVE_ARRAY_COUNT);
TRIGTIME_ARRAY      = ReadLong(fid, aTRIGTIME_ARRAY);

%判断数据位数，并读取数据，获得时基和垂直数据
fseek(fid, WAVEDESC + WAVE_DESCRIPTOR + USER_TEXT + TRIGTIME_ARRAY, 'bof');
if COMM_TYPE == 0  % byte
   wave.y=fread(fid,WAVE_ARRAY_1, 'int8');
else	%	word
   wave.y=fread(fid,WAVE_ARRAY_1, 'int16');
end;

%根据偏移值确定最终的数值
wave.y = VERTICAL_GAIN * wave.y - VERTICAL_OFFSET;
wave.x = (0:WAVE_ARRAY_COUNT-1)'*HORIZ_INTERVAL + HORIZ_OFFSET;

%关闭文件
fclose(fid);

%根据数据格式读取
function b=ReadByte(fid, Addr)
	fseek(fid,Addr,'bof');
	b=fread(fid,1,'int8');
   
function w=ReadWord(fid, Addr)
	fseek(fid,Addr,'bof');
	w=fread(fid,1,'int16');
	
function l=ReadLong(fid, Addr)
	fseek(fid,Addr,'bof');
	l=fread(fid,1,'int32');
   
function f=ReadFloat(fid, Addr)
	fseek(fid,Addr,'bof');
	f=fread(fid,1,'float32');
   
function d=ReadDouble(fid, Addr)
	fseek(fid,Addr,'bof');
	d=fread(fid,1,'float64');
   
function s=ReadString(fid, Addr)
	fseek(fid,Addr,'bof');
	s=fgets(fid,16);

function t=ReadTimestamp(fid, Addr)
	fseek(fid,Addr,'bof');
	seconds	= fread(fid,1,'float64');
   minutes	= fread(fid,1,'int8');
   hours		= fread(fid,1,'int8');
   days		= fread(fid,1,'int8');
   months	= fread(fid,1,'int8');
   year		= fread(fid,1,'int16');
   
   t=sprintf('%i.%i.%i, %i:%i:%2.0f', days, months, year, hours, minutes, seconds);
   
function t=ReadTimebase(fid, Addr)
	fseek(fid,Addr,'bof');
	e=fread(fid,1,'int16');
   
   tmp=[1 2 5];
   mant = tmp( 1+ mod(e,3));
   ex  = floor (e / 3)-12;
   
   t=mant*10^ex;   

function t=ReadFixed_vert_gain(fid, Addr)
    fseek(fid,Addr,'bof');
    e=fread(fid,1,'int16');
    tmp=[1 2 5];
    mant = tmp( 1+ mod(e,3));
    ex  = floor (e / 3)-6;
    t= mant*10^ex;   

function s=Float_to_Eng (f)
   ex= floor(log10(f)); 
   exeng=ex-mod(ex,3);
   if exeng<-18; exeng=-18; end
   if exeng>18; exeng=18; end;
   mant=f/10^exeng;
   
   prefix=('afpnum kMGPE');	%prefixes (u=micro, m=milli, k=kilo, ...)
   s=sprintf('%g%s',mant, prefix( (exeng+18)/3 +1));
