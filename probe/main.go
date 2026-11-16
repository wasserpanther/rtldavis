// probe: sweep frequencies with the repo's own demodulator and report
// every valid Davis packet that decodes. Used to find the exact receive
// frequency / ppm offset of the local station.
package main

import (
	"flag"
	"fmt"
	"log"
	"time"

	"github.com/lheijst/rtldavis/protocol"
	rtlsdr "github.com/jpoirier/gortlsdr"
)

func main() {
	start := flag.Int("start", 868000000, "start freq Hz")
	end := flag.Int("end", 868700000, "end freq Hz")
	step := flag.Int("step", 10000, "step Hz")
	dwell := flag.Int("dwell", 4000, "dwell ms per frequency")
	ppm := flag.Int("ppm", 0, "ppm correction")
	gain := flag.Int("gain", 496, "tuner gain tenths dB")
	flag.Parse()

	log.SetFlags(log.Lmicroseconds)

	dev, err := rtlsdr.Open(0)
	if err != nil {
		log.Fatal(err)
	}
	defer dev.Close()

	p := protocol.NewParser(14, "EU")
	fs := p.Cfg.SampleRate
	if err := dev.SetSampleRate(fs); err != nil {
		log.Fatal(err)
	}
	if err := dev.SetTunerGainMode(true); err != nil {
		log.Fatal(err)
	}
	if err := dev.SetTunerGain(*gain); err != nil {
		log.Printf("SetTunerGain: %s", err)
	}
	if err := dev.SetFreqCorrection(*ppm); err != nil {
		log.Printf("SetFreqCorrection: %s", err)
	}

	block := make([]byte, p.Cfg.BlockSize2)
	log.Printf("probe: start=%d end=%d step=%d dwell=%dms ppm=%d gain=%d fs=%d",
		*start, *end, *step, *dwell, *ppm, *gain, fs)

	for f := *start; f <= *end; f += *step {
		if err := dev.SetCenterFreq(f); err != nil {
			log.Printf("SetCenterFreq %d: %s", f, err)
			continue
		}
		if err := dev.ResetBuffer(); err != nil {
			log.Fatal(err)
		}
		deadline := time.Now().Add(time.Duration(*dwell) * time.Millisecond)
		got := 0
		for time.Now().Before(deadline) {
			n, err := dev.ReadSync(block, len(block))
			if err != nil || n != len(block) {
				continue
			}
			msgs := p.Parse(p.Demodulate(block))
			for _, m := range msgs {
				got++
				fmt.Printf("PACKET t=%s tuned=%d ppm=%d ID=%d data=%02X\n",
					time.Now().Format("15:04:05.000"), f, *ppm, m.ID, m.Data)
			}
		}
		if got > 0 {
			log.Printf("freq %d: %d packets", f, got)
		}
	}
	log.Printf("probe done")
}
