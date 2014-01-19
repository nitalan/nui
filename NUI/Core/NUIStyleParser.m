//
//  NUIStyleParser.m
//  NUIDemo
//
//  Created by Tom Benner on 12/4/12.
//  Copyright (c) 2012 Tom Benner. All rights reserved.
//

#import "NUIStyleParser.h"
#import "CoreParse.h"
#import "CPTokeniser.h"
#import "NUITokeniserDelegate.h"
#import "NUIParserDelegate.h"
#import "NUIStyleSheet.h"
#import "NUIRuleSet.h"

@implementation NUIStyleParser

- (NSMutableDictionary*)getStylesFromFile:(NSString*)fileName
{
    NSString* path = [[NSBundle mainBundle] pathForResource:fileName ofType:@"nss"];
    NSAssert1(path != nil, @"File \"%@\" does not exist", fileName);
    NSString* content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    NUIStyleSheet *styleSheet = [self parse:content];
    return [self consolidateRuleSets:styleSheet];
}

- (NSMutableDictionary*)getStylesFromPath:(NSString*)path
{
    NSString* content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    NUIStyleSheet *styleSheet = [self parse:content];
    return [self consolidateRuleSets:styleSheet];
}

- (NSMutableDictionary*)consolidateRuleSets:(NUIStyleSheet *)styleSheet
{
    NSMutableDictionary *consolidatedRuleSets = [[NSMutableDictionary alloc] init];
    for (NUIRuleSet *ruleSet in styleSheet.ruleSets) {
        for (NSString *selector in ruleSet.selectors) {
            if (consolidatedRuleSets[selector] == nil) {
                consolidatedRuleSets[selector] = [[NSMutableDictionary alloc] init];
            }
            [self mergeRuleSetIntoConsolidatedRuleSet:ruleSet consolidatedRuleSet:consolidatedRuleSets[selector] definitions:styleSheet.definitions];
        }
    }
    return consolidatedRuleSets;
}

- (NSMutableDictionary*)mergeRuleSetIntoConsolidatedRuleSet:(NUIRuleSet*)ruleSet consolidatedRuleSet:(NSMutableDictionary*)consolidatedRuleSet definitions:(NSDictionary*)definitions
{
    for (NSString *property in ruleSet.declarations) {
        NSString *value = ruleSet.declarations[property];
        if ([value hasPrefix:@"@"]) {
            NSString *variable = value;
            value = definitions[variable];
            
            if (!value) {
                [NSException raise:@"Undefined variable" format:@"Variable %@ is not defined", variable];
            }
        }
        consolidatedRuleSet[property] = value;
    }
    return consolidatedRuleSet;
}

- (NUIStyleSheet *)parse:(NSString *)styles
{
    CPTokeniser *tokeniser = [[CPTokeniser alloc] init];
        
    [tokeniser addTokenRecogniser:[CPWhiteSpaceRecogniser whiteSpaceRecogniser]];
    [tokeniser addTokenRecogniser:[CPQuotedRecogniser quotedRecogniserWithStartQuote:@"/*"
                                                                            endQuote:@"*/"
                                                                                name:@"Comment"]];
    
    NSCharacterSet *idCharacters = [NSCharacterSet characterSetWithCharactersInString:
                                    @"abcdefghijklmnopqrstuvwxyz"
                                    @"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                                    @"0123456789"
                                    @"-_\\."];
    NSCharacterSet *initialIdCharacters = [NSCharacterSet characterSetWithCharactersInString:
                                           @"abcdefghijklmnopqrstuvwxyz"
                                           @"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                                           @"0123456789"
                                           @"#@-_\\."];
    [tokeniser addTokenRecogniser:[CPIdentifierRecogniser identifierRecogniserWithInitialCharacters:initialIdCharacters identifierCharacters:idCharacters]];
   
    [tokeniser addTokenRecogniser:[CPKeywordRecogniser recogniserForKeyword:@":"]];
    [tokeniser addTokenRecogniser:[CPKeywordRecogniser recogniserForKeyword:@"{"]];
    [tokeniser addTokenRecogniser:[CPKeywordRecogniser recogniserForKeyword:@"}"]];
    [tokeniser addTokenRecogniser:[CPKeywordRecogniser recogniserForKeyword:@"("]];
    [tokeniser addTokenRecogniser:[CPKeywordRecogniser recogniserForKeyword:@")"]];
    [tokeniser addTokenRecogniser:[CPKeywordRecogniser recogniserForKeyword:@","]];
    [tokeniser addTokenRecogniser:[CPKeywordRecogniser recogniserForKeyword:@";"]];
    
    NUITokeniserDelegate *tokenizerDelegate = [[NUITokeniserDelegate alloc] init];
    tokeniser.delegate = tokenizerDelegate;
    
    NSString *expressionGrammar =
       @"NUIStyleSheet            ::= definitions@<NUIDefinition>* ruleSets@<NUIRuleSet>*;\n"
        "NUIRuleSet               ::= selectors@<NUISelectorSet> '{' declarations@<NUIDeclaration>* '}';\n"
        "NUISelectorSet           ::= firstSelector@<NUISelector> otherSelectors@<NUIDelimitedSelector>*;\n"
        "NUISelector              ::= name@'Identifier';\n"
        "NUIDelimitedSelector     ::= ',' selector@<NUISelector>;\n"
        "NUIDeclaration           ::= property@'Identifier' ':' value@<NUIValue> ';';\n"
        "NUIDefinition            ::= variable@'Variable' ':' value@<NUIValue> ';';\n"
        "NUIValue                 ::= <NUIAny>+;\n"
        "NUIAny                   ::= 'Identifier' | 'Variable' | '(' | ')' | ',';\n"
        ;
    
    NSError *err = nil;
    CPGrammar *grammar = [CPGrammar grammarWithStart:@"NUIStyleSheet"
                                      backusNaurForm:expressionGrammar
                                               error:&err];
    if (!grammar) {
        NSLog(@"Error creating grammar:%@", err);
        return nil;
    }
    
    CPParser *parser = [CPLALR1Parser parserWithGrammar:grammar];
    
    if (!parser)
        return nil;
    
    NUIParserDelegate *parserDelegate = [[NUIParserDelegate alloc] init];
    parser.delegate = parserDelegate;
    
    CPTokenStream *tokenStream = [tokeniser tokenise:styles];
    return [parser parse:tokenStream];
}

@end
