clear all;
clc;

%[X]=xlsread('F:\Temps\���ӻ�\a.xls',1,'a1��a65536')
%[Y]=xlsread('F:\Temps\���ӻ�\a.xls',1,'b1��b65536')
%plot(X,Y,'.-')

%��Ҫ�ж������Ƿ�Ϊ�ջ������ݵ�������
wave1=ReadLeCroyBinaryWaveform('c1.trc');
wave2=ReadLeCroyBinaryWaveform('c2.trc');

subplot(2,2,1:2);
plot(wave1.x,wave1.y,'b-',wave2.x,wave2.y,'r-');
subplot(2,2,3);
plot(wave1.x,wave1.y,'b-');
subplot(2,2,4);
plot(wave2.x,wave2.y,'r-');