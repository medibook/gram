/*
 * Copyright 2012 ZXing authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "ZXAbstractExpandedDecoder.h"
#import "ZXBitArray.h"
#import "ZXBitArrayBuilder.h"
#import "ZXDataCharacter.h"
#import "ZXErrors.h"
#import "ZXExpandedPair.h"
#import "ZXResult.h"
#import "ZXRSSExpandedReader.h"
#import "ZXRSSFinderPattern.h"
#import "ZXRSSUtils.h"

const int SYMBOL_WIDEST[5] = {7, 5, 4, 3, 1};
const int EVEN_TOTAL_SUBSET[5] = {4, 20, 52, 104, 204};
const int GSUM[5] = {0, 348, 1388, 2948, 3988};

const int WEIGHTS[23][8] = {
  {  1,   3,   9,  27,  81,  32,  96,  77},
  { 20,  60, 180, 118, 143,   7,  21,  63},
  {189, 145,  13,  39, 117, 140, 209, 205},
  {193, 157,  49, 147,  19,  57, 171,  91},
  { 62, 186, 136, 197, 169,  85,  44, 132},
  {185, 133, 188, 142,   4,  12,  36, 108},
  {113, 128, 173,  97,  80,  29,  87,  50},
  {150,  28,  84,  41, 123, 158,  52, 156},
  { 46, 138, 203, 187, 139, 206, 196, 166},
  { 76,  17,  51, 153,  37, 111, 122, 155},
  { 43, 129, 176, 106, 107, 110, 119, 146},
  { 16,  48, 144,  10,  30,  90,  59, 177},
  {109, 116, 137, 200, 178, 112, 125, 164},
  { 70, 210, 208, 202, 184, 130, 179, 115},
  {134, 191, 151,  31,  93,  68, 204, 190},
  {148,  22,  66, 198, 172,   94, 71,   2},
  {  6,  18,  54, 162,  64,  192,154,  40},
  {120, 149,  25,  75,  14,   42,126, 167},
  { 79,  26,  78,  23,  69,  207,199, 175},
  {103,  98,  83,  38, 114, 131, 182, 124},
  {161,  61, 183, 127, 170,  88,  53, 159},
  { 55, 165,  73,   8,  24,  72,   5,  15},
  { 45, 135, 194, 160,  58, 174, 100,  89}
};

const int FINDER_PAT_A = 0;
const int FINDER_PAT_B = 1;
const int FINDER_PAT_C = 2;
const int FINDER_PAT_D = 3;
const int FINDER_PAT_E = 4;
const int FINDER_PAT_F = 5;

const int FINDER_PATTERN_SEQUENCES_LEN = 10;
const int FINDER_PATTERN_SEQUENCES_SUBLEN = 11;
const int FINDER_PATTERN_SEQUENCES[FINDER_PATTERN_SEQUENCES_LEN][FINDER_PATTERN_SEQUENCES_SUBLEN] = {
  { FINDER_PAT_A, FINDER_PAT_A },
  { FINDER_PAT_A, FINDER_PAT_B, FINDER_PAT_B },
  { FINDER_PAT_A, FINDER_PAT_C, FINDER_PAT_B, FINDER_PAT_D },
  { FINDER_PAT_A, FINDER_PAT_E, FINDER_PAT_B, FINDER_PAT_D, FINDER_PAT_C },
  { FINDER_PAT_A, FINDER_PAT_E, FINDER_PAT_B, FINDER_PAT_D, FINDER_PAT_D, FINDER_PAT_F },
  { FINDER_PAT_A, FINDER_PAT_E, FINDER_PAT_B, FINDER_PAT_D, FINDER_PAT_E, FINDER_PAT_F, FINDER_PAT_F },
  { FINDER_PAT_A, FINDER_PAT_A, FINDER_PAT_B, FINDER_PAT_B, FINDER_PAT_C, FINDER_PAT_C, FINDER_PAT_D, FINDER_PAT_D },
  { FINDER_PAT_A, FINDER_PAT_A, FINDER_PAT_B, FINDER_PAT_B, FINDER_PAT_C, FINDER_PAT_C, FINDER_PAT_D, FINDER_PAT_E, FINDER_PAT_E },
  { FINDER_PAT_A, FINDER_PAT_A, FINDER_PAT_B, FINDER_PAT_B, FINDER_PAT_C, FINDER_PAT_C, FINDER_PAT_D, FINDER_PAT_E, FINDER_PAT_F, FINDER_PAT_F },
  { FINDER_PAT_A, FINDER_PAT_A, FINDER_PAT_B, FINDER_PAT_B, FINDER_PAT_C, FINDER_PAT_D, FINDER_PAT_D, FINDER_PAT_E, FINDER_PAT_E, FINDER_PAT_F, FINDER_PAT_F },
};

const int LONGEST_SEQUENCE_SIZE = FINDER_PATTERN_SEQUENCES_SUBLEN;
const int MAX_PAIRS = 11;

@interface ZXRSSExpandedReader () {
  int startEnd[2];
  int currentSequence[LONGEST_SEQUENCE_SIZE];
}

@property (nonatomic, retain) NSMutableArray *pairs;

- (BOOL)adjustOddEvenCounts:(int)numModules;
- (ZXResult *)constructResult:(NSMutableArray *)pairs error:(NSError**)error;
- (BOOL)checkChecksum;
- (BOOL)checkPairSequence:(NSMutableArray *)previousPairs pattern:(ZXRSSFinderPattern *)pattern error:(NSError**)error;
- (ZXDataCharacter *)decodeDataCharacter:(ZXBitArray *)row pattern:(ZXRSSFinderPattern *)pattern isOddPattern:(BOOL)isOddPattern leftChar:(BOOL)leftChar;
- (BOOL)findNextPair:(ZXBitArray *)row previousPairs:(NSMutableArray *)previousPairs forcedOffset:(int)forcedOffset;
- (int)nextSecondBar:(ZXBitArray *)row initialPos:(int)initialPos;
- (BOOL)isNotA1left:(ZXRSSFinderPattern *)pattern isOddPattern:(BOOL)isOddPattern leftChar:(BOOL)leftChar;
- (ZXRSSFinderPattern *)parseFoundFinderPattern:(ZXBitArray *)row rowNumber:(int)rowNumber oddPattern:(BOOL)oddPattern;
- (void)reverseCounters:(int*)counters length:(unsigned int)length;

@end

@implementation ZXRSSExpandedReader

@synthesize pairs;

- (id)init {
  if (self = [super init]) {
    self.pairs = [NSMutableArray array];
  }

  return self;
}

- (void)dealloc {
  [pairs release];

  [super dealloc];
}

- (ZXResult *)decodeRow:(int)rowNumber row:(ZXBitArray *)row hints:(ZXDecodeHints *)hints error:(NSError **)error {
  [self reset];
  if (![self decodeRow2pairs:rowNumber row:row]) {
    if (error) *error = NotFoundErrorInstance();
    return nil;
  }
  return [self constructResult:self.pairs error:error];
}

- (void)reset {
  [self.pairs removeAllObjects];
}

- (NSMutableArray *)decodeRow2pairs:(int)rowNumber row:(ZXBitArray *)row {
  while (YES) {
    ZXExpandedPair * nextPair = [self retrieveNextPair:row previousPairs:self.pairs rowNumber:rowNumber];
    if (!nextPair) {
      return nil;
    }
    [self.pairs addObject:nextPair];
    if ([nextPair mayBeLast]) {
      if ([self checkChecksum]) {
        return self.pairs;
      }
      if (nextPair.mustBeLast) {
        return nil;
      }
    }
  }
}

- (ZXResult *)constructResult:(NSMutableArray *)_pairs error:(NSError **)error {
  ZXBitArray * binary = [ZXBitArrayBuilder buildBitArray:_pairs];

  ZXAbstractExpandedDecoder * decoder = [ZXAbstractExpandedDecoder createDecoder:binary];
  NSString * resultingString = [decoder parseInformationWithError:error];
  if (!resultingString) {
    return nil;
  }

  NSArray * firstPoints = [[((ZXExpandedPair *)[_pairs objectAtIndex:0]) finderPattern] resultPoints];
  NSArray * lastPoints = [[((ZXExpandedPair *)[_pairs lastObject]) finderPattern] resultPoints];

  return [ZXResult resultWithText:resultingString
                         rawBytes:NULL
                           length:0
                     resultPoints:[NSArray arrayWithObjects:[firstPoints objectAtIndex:0], [firstPoints objectAtIndex:1], [lastPoints objectAtIndex:0], [lastPoints objectAtIndex:1], nil]
                           format:kBarcodeFormatRSSExpanded];
}

- (BOOL)checkChecksum {
  ZXExpandedPair * firstPair = [self.pairs objectAtIndex:0];
  ZXDataCharacter * checkCharacter = firstPair.leftChar;
  ZXDataCharacter * firstCharacter = firstPair.rightChar;
  int checksum = [firstCharacter checksumPortion];
  int s = 2;

  for (int i = 1; i < self.pairs.count; ++i) {
    ZXExpandedPair* currentPair = [self.pairs objectAtIndex:i];
    checksum += currentPair.leftChar.checksumPortion;
    s++;
    ZXDataCharacter* currentRightChar = currentPair.rightChar;
    if (currentRightChar != nil) {
      checksum += currentRightChar.checksumPortion;
      s++;
    }
  }

  checksum %= 211;
  int checkCharacterValue = 211 * (s - 4) + checksum;
  return checkCharacterValue == checkCharacter.value;
}

- (int)nextSecondBar:(ZXBitArray *)row initialPos:(int)initialPos {
  int currentPos;
  if ([row get:initialPos]) {
    currentPos = [row nextUnset:initialPos];
    currentPos = [row nextSet:currentPos];
  } else {
    currentPos = [row nextSet:initialPos];
    currentPos = [row nextUnset:currentPos];
  }
  return currentPos;
}

// not private for testing
- (ZXExpandedPair *)retrieveNextPair:(ZXBitArray *)row previousPairs:(NSMutableArray *)previousPairs rowNumber:(int)rowNumber {
  BOOL isOddPattern = [previousPairs count] % 2 == 0;
  ZXRSSFinderPattern * pattern;
  BOOL keepFinding = YES;
  int forcedOffset = -1;

  do {
    if (![self findNextPair:row previousPairs:previousPairs forcedOffset:forcedOffset]) {
      return nil;
    }
    pattern = [self parseFoundFinderPattern:row rowNumber:rowNumber oddPattern:isOddPattern];
    if (pattern == nil) {
      forcedOffset = [self nextSecondBar:row initialPos:startEnd[0]];
    } else {
      keepFinding = NO;
    }
  } while (keepFinding);
  NSError* error = nil;
  BOOL mayBeLast = [self checkPairSequence:previousPairs pattern:pattern error:&error];
  if (error) {
    return nil;
  }
  ZXDataCharacter * leftChar = [self decodeDataCharacter:row pattern:pattern isOddPattern:isOddPattern leftChar:YES];
  if (!leftChar) { 
    return nil;
  }
  ZXDataCharacter * rightChar;

  rightChar = [self decodeDataCharacter:row pattern:pattern isOddPattern:isOddPattern leftChar:NO];
  if (!rightChar && !mayBeLast) {
    return nil;
  }
  return [[[ZXExpandedPair alloc] initWithLeftChar:leftChar rightChar:rightChar finderPattern:pattern mayBeLast:mayBeLast] autorelease];
}

- (BOOL)checkPairSequence:(NSMutableArray *)previousPairs pattern:(ZXRSSFinderPattern *)pattern error:(NSError**)error {
  int currentSequenceLength = [previousPairs count] + 1;
  if (currentSequenceLength > LONGEST_SEQUENCE_SIZE) {
    if (error) *error = NotFoundErrorInstance();
    return NO;
  }

  for (int pos = 0; pos < [previousPairs count]; ++pos) {
    currentSequence[pos] = [[[previousPairs objectAtIndex:pos] finderPattern] value];
  }

  currentSequence[currentSequenceLength - 1] = [pattern value];

  for (int i = 0; i < FINDER_PATTERN_SEQUENCES_LEN; ++i) {
    int * validSequence = (int*)FINDER_PATTERN_SEQUENCES[i];
    if (i + 2 >= currentSequenceLength) {
      BOOL valid = YES;

      for (int pos = 0; pos < currentSequenceLength; ++pos) {
        if (currentSequence[pos] != validSequence[pos]) {
          valid = NO;
          break;
        }
      }

      if (valid) {
        return currentSequenceLength == i + 2;
      }
    }
  }

  if (error) *error = NotFoundErrorInstance();
  return NO;
}

- (BOOL)findNextPair:(ZXBitArray *)row previousPairs:(NSMutableArray *)previousPairs forcedOffset:(int)forcedOffset {
  const int countersLen = self.decodeFinderCountersLen;
  int* counters = self.decodeFinderCounters;
  counters[0] = 0;
  counters[1] = 0;
  counters[2] = 0;
  counters[3] = 0;

  int width = row.size;

  int rowOffset;
  if (forcedOffset >= 0) {
    rowOffset = forcedOffset;
  } else if ([previousPairs count] == 0) {
    rowOffset = 0;
  } else {
    ZXExpandedPair * lastPair = [previousPairs lastObject];
    rowOffset = [[[[lastPair finderPattern] startEnd] objectAtIndex:1] intValue];
  }
  BOOL searchingEvenPair = [previousPairs count] % 2 != 0;

  BOOL isWhite = NO;
  while (rowOffset < width) {
    isWhite = ![row get:rowOffset];
    if (!isWhite) {
      break;
    }
    rowOffset++;
  }

  int counterPosition = 0;
  int patternStart = rowOffset;
  for (int x = rowOffset; x < width; x++) {
    if ([row get:x] ^ isWhite) {
      counters[counterPosition]++;
    } else {
      if (counterPosition == 3) {
        if (searchingEvenPair) {
          [self reverseCounters:counters length:countersLen];
        }

        if ([ZXAbstractRSSReader isFinderPattern:counters countersLen:countersLen]) {
          startEnd[0] = patternStart;
          startEnd[1] = x;
          return YES;
        }

        if (searchingEvenPair) {
          [self reverseCounters:counters length:countersLen];
        }

        patternStart += counters[0] + counters[1];
        counters[0] = counters[2];
        counters[1] = counters[3];
        counters[2] = 0;
        counters[3] = 0;
        counterPosition--;
      } else {
        counterPosition++;
      }
      counters[counterPosition] = 1;
      isWhite = !isWhite;
    }
  }
  return NO;
}

- (void)reverseCounters:(int*)counters length:(unsigned int)length {
  for(int i = 0; i < length / 2; ++i){
    int tmp = counters[i];
    counters[i] = counters[length - i - 1];
    counters[length - i - 1] = tmp;
  }
}

- (ZXRSSFinderPattern *)parseFoundFinderPattern:(ZXBitArray *)row rowNumber:(int)rowNumber oddPattern:(BOOL)oddPattern {
  // Actually we found elements 2-5.
  int firstCounter;
  int start;
  int end;

  if (oddPattern) {
    // If pattern number is odd, we need to locate element 1 *before* the current block.

    int firstElementStart = startEnd[0] - 1;
    // Locate element 1
    while (firstElementStart >= 0 && ![row get:firstElementStart]) {
      firstElementStart--;
    }

    firstElementStart++;
    firstCounter = startEnd[0] - firstElementStart;
    start = firstElementStart;
    end = startEnd[1];
  } else {
    // If pattern number is even, the pattern is reversed, so we need to locate element 1 *after* the current block.

    start = startEnd[0];

    int firstElementStart = [row nextUnset:startEnd[1] + 1];

    end = firstElementStart;
    firstCounter = end - startEnd[1];
  }

  // Make 'counters' hold 1-4
  int countersLen = self.decodeFinderCountersLen;
  int counters[countersLen];
  for (int i = countersLen - 1; i > 0; i--) {
    counters[i] = self.decodeFinderCounters[i - 1];
  }

  counters[0] = firstCounter;
  int value = [ZXAbstractRSSReader parseFinderValue:counters countersSize:countersLen
                                  finderPatternType:RSS_PATTERNS_RSS_EXPANDED_PATTERNS];
  if (value == -1) {
    return nil;
  }
  return [[[ZXRSSFinderPattern alloc] initWithValue:value startEnd:[NSArray arrayWithObjects:[NSNumber numberWithInt:start], [NSNumber numberWithInt:end], nil] start:start end:end rowNumber:rowNumber] autorelease];
}

- (ZXDataCharacter *)decodeDataCharacter:(ZXBitArray *)row pattern:(ZXRSSFinderPattern *)pattern isOddPattern:(BOOL)isOddPattern leftChar:(BOOL)leftChar {
  int countersLen = self.dataCharacterCountersLen;
  int* counters = self.dataCharacterCounters;
  counters[0] = 0;
  counters[1] = 0;
  counters[2] = 0;
  counters[3] = 0;
  counters[4] = 0;
  counters[5] = 0;
  counters[6] = 0;
  counters[7] = 0;

  if (leftChar) {
    if (![ZXOneDReader recordPatternInReverse:row start:[[[pattern startEnd] objectAtIndex:0] intValue] counters:counters countersSize:countersLen]) {
      return nil;
    }
  } else {
    if (![ZXOneDReader recordPattern:row start:[[[pattern startEnd] objectAtIndex:1] intValue] + 1 counters:counters countersSize:countersLen]) {
      return nil;
    }
    // reverse it
    for (int i = 0, j = countersLen - 1; i < j; i++, j--) {
      int temp = counters[i];
      counters[i] = counters[j];
      counters[j] = temp;
    }
  }//counters[] has the pixels of the module

  int numModules = 17; //left and right data characters have all the same length
  float elementWidth = (float)[ZXAbstractRSSReader count:counters arrayLen:countersLen] / (float)numModules;

  for (int i = 0; i < countersLen; i++) {
    float value = 1.0f * counters[i] / elementWidth;
    int count = (int)(value + 0.5f);
    if (count < 1) {
      count = 1;
    } else if (count > 8) {
      count = 8;
    }
    int offset = i >> 1;
    if ((i & 0x01) == 0) {
      self.oddCounts[offset] = count;
      self.oddRoundingErrors[offset] = value - count;
    } else {
      self.evenCounts[offset] = count;
      self.evenRoundingErrors[offset] = value - count;
    }
  }

  if (![self adjustOddEvenCounts:numModules]) {
    return nil;
  }

  int weightRowNumber = 4 * pattern.value + (isOddPattern ? 0 : 2) + (leftChar ? 0 : 1) - 1;

  int oddSum = 0;
  int oddChecksumPortion = 0;
  for (int i = self.oddCountsLen - 1; i >= 0; i--) {
    if ([self isNotA1left:pattern isOddPattern:isOddPattern leftChar:leftChar]) {
      int weight = WEIGHTS[weightRowNumber][2 * i];
      oddChecksumPortion += self.oddCounts[i] * weight;
    }
    oddSum += self.oddCounts[i];
  }
  int evenChecksumPortion = 0;
  int evenSum = 0;
  for (int i = self.evenCountsLen - 1; i >= 0; i--) {
    if ([self isNotA1left:pattern isOddPattern:isOddPattern leftChar:leftChar]) {
      int weight = WEIGHTS[weightRowNumber][2 * i + 1];
      evenChecksumPortion += self.evenCounts[i] * weight;
    }
    evenSum += self.evenCounts[i];
  }
  int checksumPortion = oddChecksumPortion + evenChecksumPortion;

  if ((oddSum & 0x01) != 0 || oddSum > 13 || oddSum < 4) {
    return nil;
  }

  int group = (13 - oddSum) / 2;
  int oddWidest = SYMBOL_WIDEST[group];
  int evenWidest = 9 - oddWidest;
  int vOdd = [ZXRSSUtils rssValue:self.oddCounts widthsLen:self.oddCountsLen maxWidth:oddWidest noNarrow:YES];
  int vEven = [ZXRSSUtils rssValue:self.evenCounts widthsLen:self.evenCountsLen maxWidth:evenWidest noNarrow:NO];
  int tEven = EVEN_TOTAL_SUBSET[group];
  int gSum = GSUM[group];
  int value = vOdd * tEven + vEven + gSum;
  return [[[ZXDataCharacter alloc] initWithValue:value checksumPortion:checksumPortion] autorelease];
}

- (BOOL)isNotA1left:(ZXRSSFinderPattern *)pattern isOddPattern:(BOOL)isOddPattern leftChar:(BOOL)leftChar {
  return !([pattern value] == 0 && isOddPattern && leftChar);
}

- (BOOL)adjustOddEvenCounts:(int)numModules {
  int oddSum = [ZXAbstractRSSReader count:self.oddCounts arrayLen:self.oddCountsLen];
  int evenSum = [ZXAbstractRSSReader count:self.evenCounts arrayLen:self.evenCountsLen];
  int mismatch = oddSum + evenSum - numModules;
  BOOL oddParityBad = (oddSum & 0x01) == 1;
  BOOL evenParityBad = (evenSum & 0x01) == 0;
  BOOL incrementOdd = NO;
  BOOL decrementOdd = NO;
  if (oddSum > 13) {
    decrementOdd = YES;
  } else if (oddSum < 4) {
    incrementOdd = YES;
  }
  BOOL incrementEven = NO;
  BOOL decrementEven = NO;
  if (evenSum > 13) {
    decrementEven = YES;
  } else if (evenSum < 4) {
    incrementEven = YES;
  }
  
  if (mismatch == 1) {
    if (oddParityBad) {
      if (evenParityBad) {
        return NO;
      }
      decrementOdd = YES;
    } else {
      if (!evenParityBad) {
        return NO;
      }
      decrementEven = YES;
    }
  } else if (mismatch == -1) {
    if (oddParityBad) {
      if (evenParityBad) {
        return NO;
      }
      incrementOdd = YES;
    } else {
      if (!evenParityBad) {
        return NO;
      }
      incrementEven = YES;
    }
  } else if (mismatch == 0) {
    if (oddParityBad) {
      if (!evenParityBad) {
        return NO;
      }
      if (oddSum < evenSum) {
        incrementOdd = YES;
        decrementEven = YES;
      } else {
        decrementOdd = YES;
        incrementEven = YES;
      }
    } else {
      if (evenParityBad) {
        return NO;
      }
    }
  } else {
    return NO;
  }

  if (incrementOdd) {
    if (decrementOdd) {
      return NO;
    }
    [ZXAbstractRSSReader increment:self.oddCounts arrayLen:self.oddCountsLen errors:self.oddRoundingErrors];
  }
  if (decrementOdd) {
    [ZXAbstractRSSReader decrement:self.oddCounts arrayLen:self.oddCountsLen errors:self.oddRoundingErrors];
  }
  if (incrementEven) {
    if (decrementEven) {
      return NO;
    }
    [ZXAbstractRSSReader increment:self.evenCounts arrayLen:self.evenCountsLen errors:self.oddRoundingErrors];
  }
  if (decrementEven) {
    [ZXAbstractRSSReader decrement:self.evenCounts arrayLen:self.evenCountsLen errors:self.evenRoundingErrors];
  }
  return YES;
}

@end
