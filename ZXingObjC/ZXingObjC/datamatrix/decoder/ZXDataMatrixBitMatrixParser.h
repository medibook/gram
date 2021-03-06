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

@class ZXBitMatrix, ZXDataMatrixVersion;

@interface ZXDataMatrixBitMatrixParser : NSObject

@property (nonatomic, retain, readonly) ZXDataMatrixVersion* version;

- (id)initWithBitMatrix:(ZXBitMatrix *)bitMatrix error:(NSError**)error;
- (NSArray *)readCodewords;
- (BOOL)readModule:(int)row column:(int)column numRows:(int)numRows numColumns:(int)numColumns;
- (int)readUtah:(int)row column:(int)column numRows:(int)numRows numColumns:(int)numColumns;
- (int)readCorner1:(int)numRows numColumns:(int)numColumns;
- (int)readCorner2:(int)numRows numColumns:(int)numColumns;
- (int)readCorner3:(int)numRows numColumns:(int)numColumns;
- (int)readCorner4:(int)numRows numColumns:(int)numColumns;
- (ZXBitMatrix *)extractDataRegion:(ZXBitMatrix *)bitMatrix;

@end
