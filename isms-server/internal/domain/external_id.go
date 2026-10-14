package domain

import "unicode"

// CompareExternalID orders Grundschutz ids by numeric segments.
// CON.1 < CON.2 < CON.10, and CON.1.A1 < CON.1.A2 < CON.1.A10 < CON.2.A1.
func CompareExternalID(a, b string) int {
	ra := []rune(a)
	rb := []rune(b)
	i, j := 0, 0
	for i < len(ra) && j < len(rb) {
		if isASCIIDigit(ra[i]) && isASCIIDigit(rb[j]) {
			for i < len(ra) && ra[i] == '0' {
				i++
			}
			for j < len(rb) && rb[j] == '0' {
				j++
			}
			si, sj := i, j
			for i < len(ra) && isASCIIDigit(ra[i]) {
				i++
			}
			for j < len(rb) && isASCIIDigit(rb[j]) {
				j++
			}
			if li, lj := i-si, j-sj; li != lj {
				if li < lj {
					return -1
				}
				return 1
			}
			for k := 0; k < i-si; k++ {
				if ra[si+k] != rb[sj+k] {
					if ra[si+k] < rb[sj+k] {
						return -1
					}
					return 1
				}
			}
			continue
		}
		ca, cb := unicode.ToLower(ra[i]), unicode.ToLower(rb[j])
		if ca != cb {
			if ca < cb {
				return -1
			}
			return 1
		}
		i++
		j++
	}
	switch {
	case i == len(ra) && j == len(rb):
		return 0
	case i == len(ra):
		return -1
	default:
		return 1
	}
}

func isASCIIDigit(r rune) bool {
	return r >= '0' && r <= '9'
}
