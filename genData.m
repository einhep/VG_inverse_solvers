function [A,Y,X_true,S,IDX,SNR]=genData(A,SNRdes,N0)
%
% Description:      Creates non-stationary time dynamics of N0 sources
%
% Input:            A:      Design matrix/forward model of size KxN
%                   SNRdes: Requested SNR level
%                   N0:     Number of active sources
% Output:           Y:      Data matrix of size KxT, where T is the number
%                           of measurements, e.g., time samples.
%                   X_true: Activation
%                   S:      Activation states
%                   IDX:    Indices of the active sources
%                   SNR:    SNR of the generated data
%
%-----------------------------Author---------------------------------------
% Sofie Therese Hansen, DTU Compute
% March 2016
% -------------------------------------------------------------------------

[K,N] = size(A);
IDX = randi(N,1,N0);
fs = 1/200; % Sampling frequency
T = 25; % T time samples
maxFreq = randi([10 15],1,N0);
X_true = zeros(N,T);

for s = 1:N0
    Sx = 0;
    while  length(find(Sx))<2
        Minidx=1;
        %maxFreq=randi([5 15]);
        while length(Minidx)<2 || Minidx(end)-Minidx(1)<2
            Sx = randn(1,T); % creates white noise
            [b,a] = butter(2, maxFreq(s)*fs*2); % get band of interest
            Sx = filtfilt(b, a, Sx); % apply filter
            Minidx = find(abs(Sx)<(max(abs(Sx))*0.05));
        end
        Sx(1:Minidx(1)) = 0;
        Sx(Minidx(end):end) = 0; 
    end
    X_true(IDX(s),:) = Sx;
end
X_true(IDX,:) = X_true(IDX,:)./repmat(max(abs(X_true(IDX,:)),[],2),1,25);
S = (abs(X_true)>0);
%%

Y0 = A*X_true;
stdnoise = std(reshape(Y0,K*T,1))*10^(-SNRdes/20);
noise = stdnoise*randn(K,T);
Y=Y0+noise;
SNR = 10*log10(mean(var(Y0))/mean(var(noise)));

