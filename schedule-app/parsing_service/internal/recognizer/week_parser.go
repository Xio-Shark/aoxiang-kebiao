package recognizer

import (
	"regexp"
	"sort"
	"strconv"
	"strings"

	"github.com/aoxiang/schedule-parser/internal/model"
)

type WeekSpec struct {
	Start       int
	End         int
	Pattern     model.WeekPattern
	CustomWeeks []int
}

func ParseWeekText(text string) *WeekSpec {
	raw := strings.TrimSpace(text)
	if raw == "" {
		return &WeekSpec{
			Start:   1,
			End:     25,
			Pattern: model.WeekPatternAll,
		}
	}

	cleaned := strings.ReplaceAll(raw, "周", "")
	cleaned = regexp.MustCompile(`[\(（][^）\)]*[\)）]`).ReplaceAllString(cleaned, "")
	re := regexp.MustCompile(`[，,、]`)
	tokens := re.Split(cleaned, -1)

	expanded := make(map[int]bool)
	rangeRe := regexp.MustCompile(`(\d+)\s*[-~]\s*(\d+)`)
	digitRe := regexp.MustCompile(`\d+`)

	for _, token := range tokens {
		token = strings.TrimSpace(token)
		if token == "" {
			continue
		}
		if match := rangeRe.FindStringSubmatch(token); match != nil {
			a, _ := strconv.Atoi(match[1])
			b, _ := strconv.Atoi(match[2])
			min := a
			max := b
			if a > b {
				min, max = b, a
			}
			for i := min; i <= max; i++ {
				if i > 0 {
					expanded[i] = true
				}
			}
			continue
		}
		if match := digitRe.FindString(token); match != "" {
			v, _ := strconv.Atoi(match)
			if v > 0 {
				expanded[v] = true
			}
		}
	}

	if len(expanded) == 0 {
		return nil
	}

	var weeks []int
	for w := range expanded {
		weeks = append(weeks, w)
	}
	sort.Ints(weeks)

	pattern := model.WeekPatternAll
	if strings.Contains(raw, "单") {
		pattern = model.WeekPatternOdd
	} else if strings.Contains(raw, "双") {
		pattern = model.WeekPatternEven
	} else if len(tokens) > 1 {
		pattern = model.WeekPatternCustom
	}

	customWeeks := []int{}
	if pattern == model.WeekPatternCustom {
		customWeeks = weeks
	}

	return &WeekSpec{
		Start:       weeks[0],
		End:         weeks[len(weeks)-1],
		Pattern:     pattern,
		CustomWeeks: customWeeks,
	}
}
