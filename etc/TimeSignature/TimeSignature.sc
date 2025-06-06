TimeSignature {
    var <>numerator, <>denominator, <>bpm;
    var <>beat, <>measure, <>bar, <>beatDuration;

    *new { arg num = 4, denom = 4, tempo = 120;
        ^super.new.numerator_(num).denominator_(denom).setBPM(tempo).reset();
    }

    setBPM { |tempo|  // Renamed method to avoid conflict
        bpm = tempo;
        this.calcBeatDuration();
        ^this;
    }

    reset {
        beat = 1;
        measure = 1;
        bar = 1;
        this.calcBeatDuration();
    }

    calcBeatDuration {
        beatDuration = 60 / bpm;
    }

    advance {
        beat = beat + 1;
        if (beat > numerator) {
            beat = 1;
            measure = measure + 1;
            if (measure > denominator) {
                measure = 1;
                bar = bar + 1;
            }
        }
    }

    // get the current beat duration in seconds
    getBeatDuration {
        ^beatDuration;
    }

    // get tempo from beat duration
    getBPM {
        ^(60 / beatDuration);
    }

    // calculate total duration of the beats for the current measure
    getMeasureDuration {
        ^(beatDuration * numerator);
    }

    // calculate total duration of the beats for the current bar
    getBarDuration {
        ^(beatDuration * numerator * denominator);
    }

    // calculate total duration of beats for all bars
    getDuration {
        ^(beatDuration * numerator * denominator * bar);
    }

	 // Method to check if the current beat is the last in the measure
    isLastBeatInMeasure {
        ^beat == numerator;
    }

    // Method to check if the current beat is the last in the bar
    isLastBeatInBar {
        ^beat == numerator && measure == denominator;
    }

    // Method to check if the current measure is the last in the bar
    isLastMeasureInBar {
        ^measure == denominator;
    }


    // Method to check if it is the last beat in both the bar and the measure
    isLastBeatInBarAndMeasure {
        ^(this.isLastBeatInMeasure && this.isLastMeasureInBar);
    }

    isFirstBeatInMeasure {
        ^beat == 1;
    }

    isFirstMeasureInBar {
        ^(measure == 1);
    }

    isFirstBeatInBarAndMeasure {
        ^(this.isFirstBeatInMeasure && this.isFirstMeasureInBar);
    }

    printCurrentTime {
        "Beat: %, Measure: %, Bar: %\n".format(beat, measure, bar).post;
    }
}
