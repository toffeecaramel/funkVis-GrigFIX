package funkVis.dsp;

import funkVis.AudioClip;
import funkVis.Scaling;

using Lambda;
using Math;
using funkVis.dsp.FFT;

typedef BarObject =
{
	// var posX:Float;
	var freq:Float;
	var freqLo:Float;
	var freqHi:Float;
	var binLo:Int;
	var binHi:Int;
	var ratioLo:Float;
	var ratioHi:Float;
	var peak:Array<Float>;
	var hold:Int;
	// var value:Float;
}

/**
 * Helper class that can be used to create visualizations for playing audio streams
 */
class SpectralAnalyzer
{
    var bars:Array<BarObject> = [];
    var audioClip:AudioClip;
	final fftN = 4096;
    final a0 = 0.50; // => Hann(ing) window
    
    public function new(barCount:Int, audioClip:AudioClip)
    {
        this.audioClip = audioClip;
        calcBars(barCount);
    }

    // For second stage, make this return a second set of recent peaks
    public function getLevels():Array<Float>
    {
        var levels = new Array<Float>();
        // var currentEnergy:Float = 0;

		for (i in 0...bars.length)
		{
			var bar = bars[i];
			var freq = bar.freq;
			var binLo = bar.binLo;
			var binHi = bar.binHi;
			var ratioLo = bar.ratioLo;
			var ratioHi = bar.ratioHi;

			trace(bar);

			var barHeight:Float = Math.max(interpolate(binLo, ratioLo), interpolate(binHi, ratioHi));
			// check additional bins (unimplemented?)
			// check additional bins (if any) for this bar and keep the highest value
			for (j in binLo + 1...binHi)
			{
				if (amplitudes[j] > barHeight)
					barHeight = amplitudes[j];
			}

			trace(barHeight);

			barHeight = 20 * LogHelper.log10(barHeight / 32768); // gets converted to decibels
			barHeight = normalizedB(barHeight);
			trace(barHeight);
			// barHeight += 100;
			// bar.value = barHeight;
			// currentEnergy += barHeight;

			// using 0 right now for channel
			if (bar.peak[0] > 0)
			{
				bar.hold--;
				// if hold is negative, it becomes the "acceleration" for peak drop
				if (bar.hold < 0)
					bar.peak[0] += bar.hold / 200;
			}

			if (barHeight >= bar.peak[0])
			{
				bar.peak[0] = barHeight;
				bar.hold = 30; // set peak hold time to 30 frames (0.5s)
			}

			var peak = bar.peak[0];
			// var posX = bar.posX;
			// if (peak > 0 && posX >= 0 && posX < FlxG.width)
			// {
			//	 grpBars.members[i].scale.y = barHeight * 600;
			// }

            levels.push(barHeight);

			// energy.val = currentEnergy / (bars.length << 0);
			// if (energy.val >= energy.peak)
			// {
			// 	energy.peak = energy.val;
			// 	energy.hold = 30;
			// }
			// else
			// {
			// 	if (energy.hold > 0)
			// 		energy.hold--;
			// 	else if (energy.peak > 0)
			// 		energy.peak *= (30 + energy.hold--) / 30;
			// }
		}

        return levels;
    }

    function calcBars(barCount:Int)
    {
        // var barWidth:Float = FlxG.width / barCount;

        // var initX:Float = 0;
        var maxFreq:Float = 14000;
        var minFreq:Float = 30;

        var scaleMin:Float = Scaling.freqScaleBark(minFreq);
        // var unitWidth = FlxG.width / (Scaling.freqScaleBark(maxFreq) - scaleMin);
        var stride = Scaling.freqScaleBark(maxFreq) - scaleMin;

        // var a:Float = scaleMin + (0 * stride) / barCount;
        // trace(a);
        // var freqLo:Float = Scaling.invFreqScaleBark(a);
        // trace(freqLo);
        // a = scaleMin + ((0+1) * stride) / barCount;
        // trace(a);
        // var freqHi:Float = Scaling.invFreqScaleBark(a);
        // trace(freqHi);
        // var freq:Float = (freqHi + freqLo) / 2.0;
        // trace(freq);

        // var binAndRatioLo:Array<Float> = calcRatio(Std.int(freqLo));
        // trace(binAndRatioLo);
        // var binAndRatioHi:Array<Float> = calcRatio(Std.int(freqHi));
        // trace(binAndRatioHi);

        // return;

        // var posX:Float = 0;
        for (i in 0...barCount)
        {
            // i / barCount * (Scaling.freqScaleBark(maxFreq) - scaleMin)
            var freqLo:Float = Scaling.invFreqScaleBark(scaleMin + (i * stride) / barCount);
            var freqHi:Float = Scaling.invFreqScaleBark(scaleMin + ((i+1) * stride) / barCount);
            var freq:Float = (freqHi + freqLo) / 2.0;

            // var freqLo:Float = Scaling.invFreqScaleBark(scaleMin + posX / unitWidth);
            // var freq:Float = Scaling.invFreqScaleBark(scaleMin + (posX + barWidth / 2) / unitWidth);
            // var freqHi:Float = Scaling.invFreqScaleBark(scaleMin + (posX + barWidth) / unitWidth);

            var binAndRatioLo:Array<Float> = calcRatio(Std.int(freqLo));
            var binAndRatioHi:Array<Float> = calcRatio(Std.int(freqHi));

            bars.push({
                // posX: initX + posX,
                freq: freq,
                freqLo: freqLo,
                freqHi: freqHi,
                binLo: Std.int(binAndRatioLo[0]),
                binHi: Std.int(binAndRatioHi[0]),
                ratioLo: binAndRatioLo[1],
                ratioHi: binAndRatioHi[1],
                peak: [0, 0],
                hold: 0,
                // value: 0
            });

            // posX += barWidth;
        }
    }

    function calcRatio(freq):Array<Float>
    {
        var bin = freqToBin(freq, 'floor'); // find closest FFT bin
        var lower = binToFreq(bin);
        var upper = binToFreq(bin + 1);
        var ratio = LogHelper.log2(freq / lower) / LogHelper.log2(upper / lower);
        return [bin, ratio];
    }

    function freqToBin(freq, mathType:String = 'round'):Int
    {
        var bin = freq * fftN / audioClip.audioBuffer.sampleRate;
        if (mathType == 'round')
            return Math.round(bin);
        else if (mathType == 'floor')
            return Math.floor(bin);
        else if (mathType == 'ceil')
            return Math.ceil(bin);
        else
            return Std.int(bin);
    }

    function binToFreq(bin)
		return bin * audioClip.audioBuffer.sampleRate / fftN;

    var amplitudes(get, default):Array<Float> = [];
	var ampIndex:Int = 0;

	function get_amplitudes():Array<Float>
	{
		var index:Int = audioClip.currentFrame;
		if (ampIndex == index)
			return amplitudes;
		else
			ampIndex = index;

		var lilamp = [];
		final freqs = stft(index, fftN, audioClip.audioBuffer.sampleRate);

		for (k => s in freqs)
			lilamp.push(s);

		amplitudes = lilamp;

		return lilamp;
	}

    function blackmanWindow(n:Int)
		return 0.42 - a0 * Math.cos(2 * Math.PI * n / (fftN - 1)) + 0.08 * Math.cos(4 * Math.PI * n / (fftN - 1));

    // computes an STFT frame, starting at the given index within input samples
	function stft(c:Int, fftN:Int = 4096, fs:Float)
    {
        return [
            for (n in 0...fftN)
                c + n < Std.int(audioClip.audioBuffer.data.length) ? audioClip.audioBuffer.data[Std.int((c + n))] : 0.0
        ].mapi((n, x) -> x * blackmanWindow(n)).rfft().map(z -> z.scale(1 / audioClip.audioBuffer.sampleRate).magnitude);
    }

    function interpolate(bin, ratio:Float)
    {
        var value = amplitudes[bin] + (bin < amplitudes.length - 1 ? (amplitudes[bin + 1] - amplitudes[bin]) * ratio : 0);
        return Math.isNaN(value) ? -Math.NEGATIVE_INFINITY : value;
    }

    function normalizedB(value:Float)
    {
        var clamp = (val:Float, min, max) -> val <= min ? min : val >= max ? max : val;

        var maxValue = -30;
        var minValue = -65;

        // return FlxMath.remapToRange(value, minValue, maxValue, 0, 1);
        return clamp((value - minValue) / (maxValue - minValue), 0, 1);
    }
}