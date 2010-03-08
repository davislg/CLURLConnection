#import "CLURLConnection.h"

#import <Foundation/Foundation.h>

NSString *const HTTPErrorDomain = @"HTTPErrorDomain";
NSString *const HTTPBody = @"HTTPBody";


static BOOL sWantsHTTPErrorBody = NO;


static inline NSString* httpErrorDescription(NSInteger statusCode)
{
	NSString *desc = NSLocalizedStringFromTable(@"Unknowns Status Code", @"HTTPErrors", "HTTP Unknown Status Code");

	switch (statusCode)
	{
		case 400: desc = NSLocalizedStringFromTable(@"Bad Request",                     @"HTTPErrors", "HTTP Status Code 400"); break;
		case 401: desc = NSLocalizedStringFromTable(@"Unauthorized",                    @"HTTPErrors", "HTTP Status Code 401"); break;
		case 402: desc = NSLocalizedStringFromTable(@"Payment Required",                @"HTTPErrors", "HTTP Status Code 402"); break;
		case 403: desc = NSLocalizedStringFromTable(@"Forbidden",                       @"HTTPErrors", "HTTP Status Code 403"); break;
		case 404: desc = NSLocalizedStringFromTable(@"Not Found",                       @"HTTPErrors", "HTTP Status Code 404"); break;
		case 405: desc = NSLocalizedStringFromTable(@"Method Not Allowed",              @"HTTPErrors", "HTTP Status Code 405"); break;
		case 406: desc = NSLocalizedStringFromTable(@"Not Acceptable",                  @"HTTPErrors", "HTTP Status Code 406"); break;
		case 407: desc = NSLocalizedStringFromTable(@"Proxy Authentication Required",   @"HTTPErrors", "HTTP Status Code 407"); break;
		case 408: desc = NSLocalizedStringFromTable(@"Request Timeout",                 @"HTTPErrors", "HTTP Status Code 408"); break;
		case 409: desc = NSLocalizedStringFromTable(@"Conflict",                        @"HTTPErrors", "HTTP Status Code 409"); break;
		case 410: desc = NSLocalizedStringFromTable(@"Gone",                            @"HTTPErrors", "HTTP Status Code 410"); break;
		case 411: desc = NSLocalizedStringFromTable(@"Length Required",                 @"HTTPErrors", "HTTP Status Code 411"); break;
		case 412: desc = NSLocalizedStringFromTable(@"Precondition Failed",             @"HTTPErrors", "HTTP Status Code 412"); break;
		case 413: desc = NSLocalizedStringFromTable(@"Request Entity Too Large",        @"HTTPErrors", "HTTP Status Code 413"); break;
		case 414: desc = NSLocalizedStringFromTable(@"Request-URI Too Long",            @"HTTPErrors", "HTTP Status Code 414"); break;
		case 415: desc = NSLocalizedStringFromTable(@"Unsupported Media Type",          @"HTTPErrors", "HTTP Status Code 415"); break;
		case 416: desc = NSLocalizedStringFromTable(@"Requested Range Not Satisfiable", @"HTTPErrors", "HTTP Status Code 416"); break;
		case 417: desc = NSLocalizedStringFromTable(@"Expectation Failed",              @"HTTPErrors", "HTTP Status Code 417"); break;
		case 418: desc = NSLocalizedStringFromTable(@"I'm a teapot",                    @"HTTPErrors", "HTTP Status Code 418"); break;
		case 422: desc = NSLocalizedStringFromTable(@"Unprocessable Entity",            @"HTTPErrors", "HTTP Status Code 422"); break;
		case 423: desc = NSLocalizedStringFromTable(@"Locked",                          @"HTTPErrors", "HTTP Status Code 423"); break;
		case 424: desc = NSLocalizedStringFromTable(@"Failed Dependency",               @"HTTPErrors", "HTTP Status Code 424"); break;
		case 425: desc = NSLocalizedStringFromTable(@"Unordered Collection",            @"HTTPErrors", "HTTP Status Code 425"); break;
		case 426: desc = NSLocalizedStringFromTable(@"Upgrade Required",                @"HTTPErrors", "HTTP Status Code 426"); break;
		case 449: desc = NSLocalizedStringFromTable(@"Retry With",                      @"HTTPErrors", "HTTP Status Code 449"); break;
		case 500: desc = NSLocalizedStringFromTable(@"Internal Server Error",           @"HTTPErrors", "HTTP Status Code 500"); break;
		case 501: desc = NSLocalizedStringFromTable(@"Not Implemented",                 @"HTTPErrors", "HTTP Status Code 501"); break;
		case 502: desc = NSLocalizedStringFromTable(@"Bad Gateway",                     @"HTTPErrors", "HTTP Status Code 502"); break;
		case 503: desc = NSLocalizedStringFromTable(@"Service Unavailable",             @"HTTPErrors", "HTTP Status Code 503"); break;
		case 504: desc = NSLocalizedStringFromTable(@"Gateway Timeout",                 @"HTTPErrors", "HTTP Status Code 504"); break;
		case 505: desc = NSLocalizedStringFromTable(@"HTTP Version Not Supported",      @"HTTPErrors", "HTTP Status Code 505"); break;
		case 506: desc = NSLocalizedStringFromTable(@"Variant Also Negotiates",         @"HTTPErrors", "HTTP Status Code 506"); break;
		case 507: desc = NSLocalizedStringFromTable(@"Insufficient Storage",            @"HTTPErrors", "HTTP Status Code 507"); break;
		case 509: desc = NSLocalizedStringFromTable(@"Bandwidth Limit Exceeded",        @"HTTPErrors", "HTTP Status Code 509"); break;
		case 510: desc = NSLocalizedStringFromTable(@"Not Extended",                    @"HTTPErrors", "HTTP Status Code 510"); break;
	}

	return desc;
}

static inline NSError* httpError(NSURL *responseURL, NSInteger httpStatusCode, NSData *httpBody)
{
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
	                         responseURL, NSURLErrorKey,
	                         responseURL, @"NSErrorFailingURLKey",
	                         [responseURL absoluteString], NSErrorFailingURLStringKey,
	                         httpErrorDescription(httpStatusCode), NSLocalizedDescriptionKey,
	                         httpBody, HTTPBody, nil];

	return [NSError errorWithDomain:HTTPErrorDomain code:httpStatusCode userInfo:userInfo];
}



@interface CLURLConnectionDelegateProxy : NSProxy
{
	id delegate;
	NSInteger httpStatusCode;
	NSMutableData *httpBody;
	NSURL *responseURL;
}

- (void) connection:(CLURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
- (void) connection:(CLURLConnection *)connection didReceiveData:(NSData *)data;
- (void) connection:(CLURLConnection *)connection didFailWithError:(NSError *)error;
- (void) connectionDidFinishLoading:(CLURLConnection *)connection;

@end

@implementation CLURLConnectionDelegateProxy

- (id) initWithDelegate:(id)theDelegate
{
	delegate = [theDelegate retain];
	return self;
}

- (void) dealloc
{
	[delegate release];
	[super dealloc];
}

- (void) connection:(CLURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	httpStatusCode = 0;
	if ([response isKindOfClass:[NSHTTPURLResponse class]])
		httpStatusCode = [(NSHTTPURLResponse*)response statusCode];

	if (httpStatusCode >= 400)
	{
		if (sWantsHTTPErrorBody)
		{
			httpBody = [[NSMutableData alloc] init];
			responseURL = [[response URL] retain];
		}
		else
		{
			[connection cancel];

			if ([delegate respondsToSelector:@selector(connection:didFailWithError:)])
				[delegate connection:connection didFailWithError:httpError([response URL], httpStatusCode, nil)];
		}
	}
	else
	{
		if ([delegate respondsToSelector:@selector(connection:didReceiveResponse:)])
			[delegate connection:connection didReceiveResponse:response];
	}
}

- (void) connection:(CLURLConnection *)connection didReceiveData:(NSData *)data
{
	[httpBody appendData:data];

	if (httpStatusCode < 400)
	{
		if ([delegate respondsToSelector:@selector(connection:didReceiveData:)])
			[delegate connection:connection didReceiveData:data];
	}
}

- (void) connection:(CLURLConnection *)connection didFailWithError:(NSError *)error
{
	if ([delegate respondsToSelector:@selector(connection:didFailWithError:)])
		[delegate connection:connection didFailWithError:error];

	[httpBody release]; httpBody = nil;
	[responseURL release]; responseURL = nil;
}

- (void) connectionDidFinishLoading:(CLURLConnection *)connection
{
	if (httpStatusCode < 400)
	{
		if ([delegate respondsToSelector:@selector(connectionDidFinishLoading:)])
			[delegate connectionDidFinishLoading:connection];
	}
	else
	{
		if ([delegate respondsToSelector:@selector(connection:didFailWithError:)])
			[delegate connection:connection didFailWithError:httpError(responseURL, httpStatusCode, httpBody)];
	}

	[httpBody release]; httpBody = nil;
	[responseURL release]; responseURL = nil;
}

- (BOOL) respondsToSelector:(SEL)selector
{
	if (selector == @selector(connection:didReceiveResponse:) ||
	    selector == @selector(connection:didReceiveData:) ||
	    selector == @selector(connection:didFailWithError:) ||
	    selector == @selector(connectionDidFinishLoading:))
		return YES;
	else
		return [delegate respondsToSelector:selector];
}

- (NSMethodSignature *) methodSignatureForSelector:(SEL)selector
{
	return [delegate methodSignatureForSelector:selector];
}

- (void) forwardInvocation:(NSInvocation *)invocation
{
	[invocation invokeWithTarget:delegate];
}

@end



@implementation CLURLConnection

+ (void) setWantsHTTPErrorBody:(BOOL)wantsHTTPErrorBody
{
	sWantsHTTPErrorBody = wantsHTTPErrorBody;
}

+ (id) connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate
{
	return [[[self alloc] initWithRequest:request delegate:delegate] autorelease];
}

- (id) initWithRequest:(NSURLRequest *)request delegate:(id)delegate startImmediately:(BOOL)startImmediately
{
	isScheduled = startImmediately;
	CLURLConnectionDelegateProxy *proxy = [[[CLURLConnectionDelegateProxy alloc] initWithDelegate:delegate] autorelease];
	return [super initWithRequest:request delegate:proxy startImmediately:startImmediately];
}

- (id) initWithRequest:(NSURLRequest *)request delegate:(id)delegate
{
	return [self initWithRequest:request delegate:delegate startImmediately:YES];
}

- (void) scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode
{
	isScheduled = YES;
	[super scheduleInRunLoop:runLoop forMode:mode];
}

- (void) start
{
	if (!isScheduled)
		[self scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

	[super start];
}

@end
