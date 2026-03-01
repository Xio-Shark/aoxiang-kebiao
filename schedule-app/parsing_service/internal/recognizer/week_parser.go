// Package recognizer 负责文本识别和规范化
package recognizer

import (
	"regexp"
	"strconv"
	"strings"
)

var (
	// 周次正则表达式
	weekRangeRegex    = regexp.MustCompile(`^第?(\d+)[\-\~到](\d+)(?:周)?(.*)$`)                 // 1-16周, 第1-16周
	weekDiscreteRegex = regexp.MustCompile(`^第?((?:\d+,?)+)(?:周)?$`)                          // 1,3,5,7周
	weekSingleRegex   = regexp.MustCompile(`^第?(\d+)(?:周)?$`)                                 // 第8周
	weekOddEvenRegex  = regexp.MustCompile(`^第?(\d+)[\-\~到](\d+)(?:周)?\s*[（\(]?(单|双)[）\)]?$`) // 1-16周(单), 1-16周单

	// 节次正则
	sectionRangeRegex  = regexp.MustCompile(`^第?(\d+)[\-\~到](\d+)(?:节)?$`) // 1-2节
	sectionSingleRegex = regexp.MustCompile(`^第?(\d+)(?:节)?$`)             // 第1节

	// 星期正则
	weekdayRegexes = []struct {
		pattern *regexp.Regexp
		value   int
	}{
		{regexp.MustCompile(`^周?一|^星期[一1]|^Mon`), 1},
		{regexp.MustCompile(`^周?二|^星期[二2]|^Tue`), 2},
		{regexp.MustCompile(`^周?三|^星期[三3]|^Wed`), 3},
		{regexp.MustCompile(`^周?四|^星期[四4]|^Thu`), 4},
		{regexp.MustCompile(`^周?五|^星期[五5]|^Fri`), 5},
		{regexp.MustCompile(`^周?六|^星期[六6]|^Sat`), 6},
		{regexp.MustCompile(`^周?日|^星期[日天日7]|^Sun`), 7},
	}
)

// WeekRange 周次范围
type WeekRange struct {
	Start       int    // 开始周
	End         int    // 结束周
	Pattern     string // all, odd, even
	CustomWeeks []int  // 自定义周次
	Raw         string // 原始文本
}

// SectionRange 节次范围
type SectionRange struct {
	Start int
	End   int
	Raw   string
}

// NormalizeWeekText 规范化周次文本
func NormalizeWeekText(raw string) (*WeekRange, error) {
	raw = preprocessText(raw)

	// 空值检查
	if raw == "" {
		return &WeekRange{Start: 1, End: 16, Pattern: "all", Raw: raw}, nil
	}

	// 尝试匹配单双周模式: 1-16周(单)
	if matches := weekOddEvenRegex.FindStringSubmatch(raw); matches != nil {
		start, _ := strconv.Atoi(matches[1])
		end, _ := strconv.Atoi(matches[2])
		pattern := matches[3]

		var weekPattern string
		if pattern == "单" {
			weekPattern = "odd"
		} else {
			weekPattern = "even"
		}

		return &WeekRange{
			Start:   start,
			End:     end,
			Pattern: weekPattern,
			Raw:     raw,
		}, nil
	}

	// 尝试匹配范围: 1-16周
	if matches := weekRangeRegex.FindStringSubmatch(raw); matches != nil {
		start, _ := strconv.Atoi(matches[1])
		end, _ := strconv.Atoi(matches[2])

		// 检查是否有单双周标记
		remain := matches[3]
		pattern := "all"
		if strings.Contains(remain, "单") {
			pattern = "odd"
		} else if strings.Contains(remain, "双") {
			pattern = "even"
		}

		return &WeekRange{
			Start:   start,
			End:     end,
			Pattern: pattern,
			Raw:     raw,
		}, nil
	}

	// 尝试匹配离散周次: 1,3,5,7周
	if matches := weekDiscreteRegex.FindStringSubmatch(raw); matches != nil {
		nums := extractNumbers(matches[1])
		if len(nums) > 0 {
			start := nums[0]
			end := nums[len(nums)-1]

			return &WeekRange{
				Start:       start,
				End:         end,
				Pattern:     "custom",
				CustomWeeks: nums,
				Raw:         raw,
			}, nil
		}
	}

	// 尝试匹配单周: 第8周
	if matches := weekSingleRegex.FindStringSubmatch(raw); matches != nil {
		week, _ := strconv.Atoi(matches[1])
		return &WeekRange{
			Start:   week,
			End:     week,
			Pattern: "all",
			Raw:     raw,
		}, nil
	}

	return nil, NewParseError("WEEK_PARSE_FAILED", "无法解析周次文本: "+raw)
}

// NormalizeSectionText 规范化节次文本
func NormalizeSectionText(raw string) (*SectionRange, error) {
	raw = preprocessText(raw)

	// 尝试匹配范围: 1-2节
	if matches := sectionRangeRegex.FindStringSubmatch(raw); matches != nil {
		start, _ := strconv.Atoi(matches[1])
		end, _ := strconv.Atoi(matches[2])
		return &SectionRange{
			Start: start,
			End:   end,
			Raw:   raw,
		}, nil
	}

	// 尝试匹配单节: 第1节
	if matches := sectionSingleRegex.FindStringSubmatch(raw); matches != nil {
		section, _ := strconv.Atoi(matches[1])
		return &SectionRange{
			Start: section,
			End:   section,
			Raw:   raw,
		}, nil
	}

	return nil, NewParseError("SECTION_PARSE_FAILED", "无法解析节次文本: "+raw)
}

// ParseWeekday 解析星期
func ParseWeekday(raw string) (int, error) {
	raw = preprocessText(raw)

	for _, re := range weekdayRegexes {
		if re.pattern.MatchString(raw) {
			return re.value, nil
		}
	}

	// 尝试直接解析数字
	if num, err := strconv.Atoi(raw); err == nil && num >= 1 && num <= 7 {
		return num, nil
	}

	return 0, NewParseError("WEEKDAY_PARSE_FAILED", "无法解析星期: "+raw)
}

// ExpandWeeks 展开周次列表
func ExpandWeeks(r *WeekRange) []int {
	var weeks []int

	switch r.Pattern {
	case "odd":
		for w := r.Start; w <= r.End; w++ {
			if w%2 == 1 {
				weeks = append(weeks, w)
			}
		}
	case "even":
		for w := r.Start; w <= r.End; w++ {
			if w%2 == 0 {
				weeks = append(weeks, w)
			}
		}
	case "custom":
		return r.CustomWeeks
	default: // all
		for w := r.Start; w <= r.End; w++ {
			weeks = append(weeks, w)
		}
	}

	return weeks
}

// preprocessText 预处理文本
func preprocessText(text string) string {
	// 转半角
	text = fullWidthToHalfWidth(text)
	// 去空格
	text = strings.TrimSpace(text)
	// 统一连字符
	text = strings.ReplaceAll(text, "～", "-")
	return text
}

// fullWidthToHalfWidth 全角转半角
func fullWidthToHalfWidth(s string) string {
	var result []rune
	for _, r := range s {
		if r >= 0xFF01 && r <= 0xFF5E {
			result = append(result, r-0xFEE0)
		} else if r == 0x3000 {
			result = append(result, ' ')
		} else {
			result = append(result, r)
		}
	}
	return string(result)
}

// extractNumbers 提取数字列表
func extractNumbers(s string) []int {
	re := regexp.MustCompile(`\d+`)
	matches := re.FindAllString(s, -1)

	var nums []int
	for _, m := range matches {
		n, _ := strconv.Atoi(m)
		nums = append(nums, n)
	}
	return nums
}

// ParseError 解析错误
type ParseError struct {
	Code    string
	Message string
}

func (e *ParseError) Error() string {
	return e.Message
}

// NewParseError 创建解析错误
func NewParseError(code, message string) *ParseError {
	return &ParseError{
		Code:    code,
		Message: message,
	}
}
