package com.botscrew;

import com.amazon.ask.Skills;
import com.amazon.ask.dispatcher.request.handler.RequestHandler;
import com.amazon.ask.servlet.SkillServlet;
import com.botscrew.constant.PropertyKey;
import com.botscrew.properties.Property;
import org.springframework.stereotype.Component;

import javax.servlet.annotation.WebServlet;
import java.util.List;

@Component
@WebServlet
public class MainServlet extends SkillServlet {

    public MainServlet(List<RequestHandler> handlers, Property property) {
        super(Skills.standard()
                .addRequestHandlers(handlers)
                .withSkillId(property.getStringPropertyByKey(PropertyKey.SKILL_ID))
                .build());
    }
}