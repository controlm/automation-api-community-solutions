package com.botscrew.handler;

import com.botscrew.annotation.IntentHandler;
import com.botscrew.constant.Intent;
import com.botscrew.processor.AbstractRequestProcessor;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
@IntentHandler(intent = Intent.FALLBACK_INTENT)
@RequiredArgsConstructor
public class FallbackRequestHandler extends AbstractRequestProcessor {

}